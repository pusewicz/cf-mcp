/*
	Sample Header for Testing
*/

#ifndef SAMPLE_H
#define SAMPLE_H

/**
 * @struct   TestStruct
 * @category test
 * @brief    A test structure for unit testing.
 * @remarks  This is a sample struct used to test the parser.
 * @related  test_function TestEnum
 */
typedef struct TestStruct
{
	/* @member The name field. */
	const char* name;

	/* @member The value field. */
	int value;
} TestStruct;
// @end

/**
 * @enum     TestEnum
 * @category test
 * @brief    A test enumeration.
 * @related  TestStruct test_function
 */
#define TEST_ENUM_DEFS \
	/* @entry First test value. */ \
	CF_ENUM(TEST_VALUE_ONE, 0) \
	/* @entry Second test value. */ \
	CF_ENUM(TEST_VALUE_TWO, 1) \
	/* @end */

typedef enum TestEnum
{
	#define CF_ENUM(K, V) K = V,
	TEST_ENUM_DEFS
	#undef CF_ENUM
} TestEnum;

/**
 * @function test_function
 * @category test
 * @brief    A test function for unit testing.
 * @param    input    The input parameter.
 * @param    count    The count parameter.
 * @return   Returns a TestStruct with the processed data.
 * @remarks  This function is used for testing purposes only.
 * @related  TestStruct TestEnum
 */
CF_API TestStruct CF_CALL test_function(const char* input, int count);

/**
 * @function another_function
 * @category other
 * @brief    Another function in a different category.
 * @return   Returns an integer.
 */
int another_function(void);

#endif
