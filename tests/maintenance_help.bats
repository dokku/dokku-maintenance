#!/usr/bin/env bats

load 'test_helper'

@test "maintenance:help lists all subcommands" {
  run dokku maintenance:help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dokku maintenance"* ]]
  [[ "$output" == *"Manage the maintenance mode for an app"* ]]
  [[ "$output" == *"maintenance:custom-page"* ]]
  [[ "$output" == *"maintenance:custom-page-export"* ]]
  [[ "$output" == *"maintenance:disable"* ]]
  [[ "$output" == *"maintenance:enable"* ]]
  [[ "$output" == *"maintenance:report"* ]]
}

@test "dokku maintenance without a subcommand prints help" {
  run dokku maintenance
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dokku maintenance"* ]]
  [[ "$output" == *"maintenance:enable"* ]]
}

@test "dokku help includes the maintenance summary" {
  run dokku help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Manage the maintenance mode for an app"* ]]
}
