#!/usr/bin/env bash
set -euo pipefail
./gradlew clean build test jacocoTestReport \
  checkstyleMain checkstyleTest \
  spotbugsMain spotbugsTest \
  pmdMain pmdTest