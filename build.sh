#!/bin/bash
set -ex
yosys hub75e.ys
$TD_HOME/bin/td build.tcl
