#!/bin/bash
first_script="./first_script.sh"
total_number_of_test=0
number_of_successful_test=0
number_of_failed_test=0
run_test(){

local expected="The success"
echo "Test number: $((total_number_of_test ))"
echo "Arguments : $@"
local result
result=$("$first_script" "$@"|tee /dev/tty | tail -1)
if  [[ "$result" == "$expected" ]]; then 
((number_of_successful_test+=1))
else 
((number_of_failed_test+=1))
fi
((total_number_of_test+=1))

}

run_test
run_test "test_data"
run_test "i_dont_know" "50" "50"
run_test "50" "50" "50"
run_test "test_data" "2500" "50" "lishny"
run_test  "test_data" "ff" "50"
run_test "test_data" "50" "ff"
run_test "test_data" "50.5" "120"
run_test "test_data1" "100" "50"
run_test "test_data" "5000" "90"
run_test "test_data"  "15000" "75"
run_test "test_data" "1360" "100"
run_test "test_data" "2000" "10"
echo "The total number: $total_number_of_test"
echo "Passed: $number_of_successful_test"
echo "Failed: $number_of_failed_test"
