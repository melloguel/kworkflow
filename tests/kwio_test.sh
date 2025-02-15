#!/bin/bash

include './tests/utils.sh'
include './src/kwio.sh'
include './src/kwlib.sh'

# NOTE: All executions off 'alert_completion' in this test file must be done
# inside a subshell (i.e. "$(alert_completion ...)"), because this function
# invokes other commands in the background. So if not done inside a subshell,
# the function will return before the background commands finish.

declare -A configurations
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

function test_ask_with_default()
{
  local output=''
  local expected_output=''
  local assert_equals_message=''

  # Default option showing
  expected_output=$'Insert something here (lala): \nsomething'
  assert_equals_message='Default answer and user answer are different.'
  output=$(printf 'something\n' | ask_with_default 'Insert something here' 'lala' '' 'TEST_MODE')
  assert_equals_helper "$assert_equals_message" "$LINENO" "$expected_output" "$output"

  expected_output=$'Insert something here (lala): \nlala'
  assert_equals_message='User selected default answer.'
  output=$(printf '\n' | ask_with_default 'Insert something here' 'lala' '' 'TEST_MODE')
  assert_equals_helper "$assert_equals_message" "$LINENO" "$expected_output" "$output"

  # Default option not showing (third parameter not empty)
  expected_output=$'Insert something here: \nsomething'
  assert_equals_message='Not showing default answer, user answered different.'
  output=$(printf 'something\n' | ask_with_default 'Insert something here' 'lala' 'false' 'TEST_MODE')
  assert_equals_helper "$assert_equals_message" "$LINENO" "$expected_output" "$output"

  expected_output=$'Insert something here: \nlala'
  assert_equals_message='Not showing default answer, user selected it.'
  output=$(printf '\n' | ask_with_default 'Insert something here' 'lala' 'false' 'TEST_MODE')
  assert_equals_helper "$assert_equals_message" "$LINENO" "$expected_output" "$output"
}

function test_ask_yN()
{
  local assert_equals_message=''

  assert_equals_message='Default answer: no, user answer: y'
  output=$(printf 'y\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: no, user answer: Y'
  output=$(printf 'Y\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: no, user answer: Yes'
  output=$(printf 'Yes\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: no, user answer: invalid (sim)'
  output=$(printf 'Sim\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: no, user answer: No'
  output=$(printf 'No\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: no, user answer: N'
  output=$(printf 'N\n' | ask_yN 'Test message')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  # Tests with default option selected
  assert_equals_message='Default answer: N, user answer: y'
  output=$(printf 'y\n' | ask_yN 'Test message' 'N')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: y, user answer: Y'
  output=$(printf 'Y\n' | ask_yN 'Test message' 'y')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: y, user answer: default'
  output=$(printf '\n' | ask_yN 'Test message' 'y')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: Y, user answer: n'
  output=$(printf 'n\n' | ask_yN 'Test message' 'Y')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: n, user answer: N'
  output=$(printf 'N\n' | ask_yN 'Test message' 'n')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: n, user anser: default'
  output=$(printf '\n' | ask_yN 'Test message' 'n')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  # Invalid default
  assert_equals_message='Default answer: invalid (lala), user answer: default'
  output=$(printf '\n' | ask_yN 'Test message' 'lala')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: invalid (lala), user answer: n'
  output=$(printf 'n\n' | ask_yN 'Test message' 'lala')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: invalid (lala), user answer: y'
  output=$(printf 'y\n' | ask_yN 'Test message' 'lala')
  assert_equals_helper "$assert_equals_message" "$LINENO" '1' "$output"

  assert_equals_message='Default answer: invalid (lalaYes), user answer: default (no)'
  output=$(printf '\n' | ask_yN 'Test message' 'lalaYes')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: invalid (lalaNo), user answer: default (no)'
  output=$(printf '\n' | ask_yN 'Test message' 'lalaNo')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  # Invalid answer
  assert_equals_message='Default answer: invalid (lala), user answer: no (invalid: lalaYes)'
  output=$(printf 'lalaYes\n' | ask_yN 'Test message' 'lala')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"

  assert_equals_message='Default answer: invalid (lala), user answer: no (invalid: lalano)'
  output=$(printf 'lalano\n' | ask_yN 'Test message' 'lala')
  assert_equals_helper "$assert_equals_message" "$LINENO" '0' "$output"
}

invoke_shunit
