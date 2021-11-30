#!/bin/bash

include './tests/utils.sh'
include './src/kwio.sh'
include './src/kwlib.sh'

# NOTE: All executions off 'alert_completion' in this test file must be done
# inside a subshell (i.e. "$(alert_completion ...)"), because this function
# invokes other commands in the background. So if not done inside a subshell,
# the function will return before the background commands finish.

declare -A configurations
declare -g load_module_text_path="$PWD/tests/samples/load_module_text_test_samples/"

sound_file="$PWD/tests/.kwio_test_aux/sound.file"
visual_file="$PWD/tests/.kwio_test_aux/visual.file"

function setUp()
{
  mkdir -p tests/.kwio_test_aux
  configurations['sound_alert_command']="touch $sound_file"
  configurations['visual_alert_command']="touch $visual_file"
}

function tearDown()
{
  rm -rf tests/.kwio_test_aux
}

function test_alert_completion_options()
{
  configurations['alert']='n'

  rm -f "$sound_file" "$visual_file"
  alert_completion '' '--alert=vs'
  wait "$!"
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's vs option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  alert_completion '' '--alert=sv'
  wait "$!"
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's sv option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  alert_completion '' '--alert=s'
  wait "$!"
  [[ -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's s option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  alert_completion '' '--alert=v'
  wait "$!"
  [[ ! -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's v option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  alert_completion '' '--alert=n'
  wait "$!"
  [[ ! -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's n option didn't work." $?

  true
}

function test_alert_completition_validate_config_file_options()
{
  mkdir -p tests/.kwio_test_aux

  rm -f "$sound_file" "$visual_file"
  configurations['alert']='vs'
  alert_completion '' ''
  wait "$!"
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's vs option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations['alert']='sv'
  alert_completion '' ''
  wait "$!"
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's sv option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations['alert']='s'
  alert_completion '' ''
  wait "$!"
  [[ -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's s option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations['alert']='v'
  alert_completion '' ''
  wait "$!"
  [[ ! -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's v option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations['alert']='n'
  alert_completion '' ''
  wait "$!"
  [[ ! -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's n option didn't work." $?

  true
}

function test_alert_completion_visual_alert()
{
  local output
  local expected='TESTING COMMAND'

  configurations['visual_alert_command']='/bin/printf "%s\n" "$COMMAND"'
  output="$(alert_completion "$expected" '--alert=v')"
  assertEquals 'Variable v should exist.' "$expected" "$output"
}

function test_alert_completion_sound_alert()
{
  local output
  local expected='TESTING COMMAND'

  configurations['sound_alert_command']='/bin/printf "%s\n" "$COMMAND"'
  output="$(alert_completion "$expected" '--alert=s')"
  assertEquals 'Variable s should exist.' "$expected" "$output"
}

function test_load_module_text_good_files()
{

  load_module_text "$load_module_text_path/file_correct" "1" > /dev/null
  assertEquals 'Should work without any errors.' "0" "$?"

  assertEquals 'Key1' 'Hello, there! How are you? I hope you are enjoying reading this test suit!' "${module_text_dictionary[key1]}"
  assertEquals 'Key2' 'Hey, you still there? []' "${module_text_dictionary[key2]}"
  assertEquals 'Key3' 'This should work with multiple lines.
Line 1
Line 2
Line 3
Line 4
Line 5' "${module_text_dictionary[key3]}"
  assertEquals 'Key4' 'done.' "${module_text_dictionary[key4]}"
  assertEquals 'Key5' '' "${module_text_dictionary[key5]}"
  assertEquals 'Key6' '




The one above should have an empty value.
' "${module_text_dictionary[key6]}"
  assertEquals 'Key7' '
This value should be ok
' "${module_text_dictionary[key7]}"
}

function test_load_module_text_bad_keys()
{
  # Test invalid keys and gets the right kinds of exceptions
  exp="[ERROR]:$load_module_text_path/file_wrong_key:7: keys should be alphanum chars
[ERROR]:$load_module_text_path/file_wrong_key:10: keys should be alphanum chars
[ERROR]:$load_module_text_path/file_wrong_key:13: keys should be alphanum chars
[ERROR]:$load_module_text_path/file_wrong_key:16: keys should be alphanum chars
[ERROR]:$load_module_text_path/file_wrong_key:19: keys should be alphanum chars"
  out=$(load_module_text "$load_module_text_path/file_wrong_key" "1")
  assertEquals 'This file has invalid keys, this should return multiple errors.' "1" "$?"
  assertEquals 'The ERROR message is not consistent with the error code or is incomplete.' "$exp" "$out"
}

function test_load_module_text_bad_files()
{
  # Merge the next 2 and call them invalid file
  load_module_text "$load_module_text_path/file_without_key" "1" > /dev/null
  assertEquals 'This file has no keys, this should return an error.' "2" "$?"

  load_module_text "$load_module_text_path/file_empty" "1" > /dev/null
  assertEquals 'This file is empty, this should return an error.' "4" "$?"

  # Test file does not exist exception
  load_module_text "$load_module_text_path/file_does_not_exist_(do not create)" "1" > /dev/null
  assertEquals 'This file does not exist, this should return an error.' "3" "$?"
}

invoke_shunit
