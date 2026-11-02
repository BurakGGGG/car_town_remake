#!/usr/bin/env bash
# MOTOR SES LABORATUVARI: araç motor seslerini tasarla, dinle, kaydet, pişir.
#   tools/engine_lab.sh              (Şahin ile açılır)
#   tools/engine_lab.sh -- toyota_supra   (o araçla açılır)
# Ayrıntı: tools/engine_lab/engine_lab_ui.gd
set -euo pipefail
cd "$(dirname "$0")/.."
exec godot-4 --path . -s res://tools/engine_lab/engine_lab.gd "$@"
