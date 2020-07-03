#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "sdkconfig.h"

#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "lwip/netdb.h"

/* FreeRTOS event group to signal when we are connected*/
static EventGroupHandle_t s_wifi_event_group;

/* The event group allows multiple bits for each event, but we only care about two events:
 * - we are connected to the AP with an IP
 * - we failed to connect after the maximum amount of retries */
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static const char *TAG = "wifi station";

static int s_retry_num = 0;

static void event_handler(void* arg, esp_event_base_t event_base,
			  int32_t event_id, void* event_data)
{
  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
    esp_wifi_connect();
  } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
    if (s_retry_num < CONFIG_WIFI_MAXIMUM_RETRY) {
      esp_wifi_connect();
      s_retry_num++;
      ESP_LOGI(TAG, "retry to connect to the AP");
    } else {
      xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
    }
    ESP_LOGI(TAG,"connect to the AP fail");
  } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
    ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
    ESP_LOGI(TAG, "got ip:%s",
	     ip4addr_ntoa(&event->ip_info.ip));
    s_retry_num = 0;
    xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
  }
}

static void wifi_init_sta()
{
  s_wifi_event_group = xEventGroupCreate();

  tcpip_adapter_init();

  ESP_ERROR_CHECK(esp_event_loop_create_default());

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL));

  wifi_config_t wifi_config =
    {
     .sta =
     {
      .ssid = CONFIG_WIFI_SSID,
      .password = CONFIG_WIFI_PASSWORD,
      .pmf_cfg =
      {
       .capable = true,
       .required = false
      },
     },
    };
  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA) );
  ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config) );
  ESP_ERROR_CHECK(esp_wifi_start() );

  ESP_LOGI(TAG, "wifi_init_sta finished.");

  /* Waiting until either the connection is established (WIFI_CONNECTED_BIT) or connection failed for the maximum
   * number of re-tries (WIFI_FAIL_BIT). The bits are set by event_handler() (see above) */
  EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
					 WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
					 pdFALSE,
					 pdFALSE,
					 portMAX_DELAY);

  /* xEventGroupWaitBits() returns the bits before the call returned, hence we can test which event actually
   * happened. */
  if (bits & WIFI_CONNECTED_BIT) {
    ESP_LOGI(TAG, "connected to ap SSID:%s password:%s",
	     CONFIG_WIFI_SSID, CONFIG_WIFI_PASSWORD);
  } else if (bits & WIFI_FAIL_BIT) {
    ESP_LOGI(TAG, "Failed to connect to SSID:%s, password:%s",
	     CONFIG_WIFI_SSID, CONFIG_WIFI_PASSWORD);
  } else {
    ESP_LOGE(TAG, "UNEXPECTED EVENT");
  }

  ESP_ERROR_CHECK(esp_event_handler_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler));
  ESP_ERROR_CHECK(esp_event_handler_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler));
  vEventGroupDelete(s_wifi_event_group);
}

#define PIN_NUM_MISO 19
#define PIN_NUM_MOSI 23
#define PIN_NUM_CLK  18
#define PIN_NUM_CS    5

spi_device_handle_t spi_led;

static void spi_init(void)
{
  esp_err_t ret;
  spi_bus_config_t buscfg =
    {
     .miso_io_num=PIN_NUM_MISO,
     .mosi_io_num=PIN_NUM_MOSI,
     .sclk_io_num=PIN_NUM_CLK,
     .quadwp_io_num=-1,
     .quadhd_io_num=-1,
     .max_transfer_sz=0
    };
  spi_device_interface_config_t devcfg =
    {
     .command_bits=0,
     .address_bits=0,
     .dummy_bits=0,
     .clock_speed_hz=4000000,	//Clock out at 4MHz
     .duty_cycle_pos=128,
     .mode=0,                   //SPI mode 0
     .cs_ena_posttrans=1,
     .spics_io_num=-1,          //no hardware CS pin
     .queue_size=1,
     .flags=0,
    };

    ret=spi_bus_initialize(VSPI_HOST, &buscfg, 0);
    assert(ret==ESP_OK);
    ret=spi_bus_add_device(VSPI_HOST, &devcfg, &spi_led);
    assert(ret==ESP_OK);
}

static esp_err_t led_writen(uint8_t *buf, size_t len)
{
  esp_err_t ret;
  static spi_transaction_t trans;
  memset(&trans, 0, sizeof(spi_transaction_t));
  trans.length = 8*len;
  trans.tx_buffer = buf;
  //printf("do transfer\n");
  ret = spi_device_transmit(spi_led, &trans);
  return ret;
}

static uint8_t ledbuf[CONFIG_MSG_LENGTH];

#define LPKT_SIZE 1400
struct lpacket {
  uint8_t header;
  uint8_t index;
  uint8_t data[LPKT_SIZE];
} lpkt;

#define SPI_LENGTH (8*4)

void udp_task(void *arg)
{
  wifi_init_sta();

  struct sockaddr_in caddr;
  struct sockaddr_in saddr;
  int sock = socket(AF_INET, SOCK_DGRAM, 0);
  if (sock < 0) {
    printf("UDP socket can't be opened.\n");
    vTaskDelete(NULL);
  }

  saddr.sin_family = AF_INET;
  saddr.sin_addr.s_addr = htonl(INADDR_ANY);
  saddr.sin_port = htons(CONFIG_UDP_PORT);
  if (bind (sock, (struct sockaddr *)&saddr, sizeof(saddr)) < 0) {
    printf("Failed to bind UDP socket.\n");
    vTaskDelete(NULL);
  }

  while(true) {
    socklen_t clen;
    ssize_t n = recvfrom(sock, (char *)&lpkt, sizeof(lpkt), 0,
			 (struct sockaddr *)&caddr, &clen);
    if (n < 0) {
      printf("Failed to recv UDP socket.\n");
    }
    if (n < 3) {
      continue;
    }
    // handle packet header 0xAA/0xE5
    if (lpkt.header != 0xaa && lpkt.header != 0xe5) {
      // ignore this packet
      printf("bad packet (size %d) start with %02x\n", n, lpkt.header);
      continue;
    }
    size_t ofs = lpkt.index * LPKT_SIZE;
    if (ofs + (n-2) <= sizeof(ledbuf))
      memcpy(&ledbuf[ofs], lpkt.data, n-2);
    if (lpkt.header == 0xe5) {
      //printf("end packet (idx %d)\n", lpkt.index);
      // end packet
      gpio_set_level(PIN_NUM_CS, 0);
      for (int i = 0; i < CONFIG_MSG_LENGTH; i += SPI_LENGTH) {
	led_writen(&ledbuf[i], SPI_LENGTH);
      }
      gpio_set_level(PIN_NUM_CS, 1);
    } else {
      ;//printf("detect packet (idx %d)\n", lpkt.index);
    }
  }
}

void app_main()
{
  //Initialize NVS
  nvs_flash_init();

  gpio_reset_pin(PIN_NUM_CS);
  gpio_set_level(PIN_NUM_CS, 1);
  gpio_set_direction(PIN_NUM_CS, GPIO_MODE_OUTPUT);

  spi_init();

  memset(ledbuf, 0, CONFIG_MSG_LENGTH);
  gpio_set_level(PIN_NUM_CS, 0);
  for (int i = 0; i < CONFIG_MSG_LENGTH; i += SPI_LENGTH) {
    led_writen(&ledbuf[i], SPI_LENGTH);
  }
  gpio_set_level(PIN_NUM_CS, 1);

  xTaskCreate(udp_task, "udp_task", 8192, NULL, 3, NULL);
 
  while(true) {
    vTaskDelay(1000 / portTICK_PERIOD_MS);
  }
}
