use inc::Module::Install;
name 'WebService-TeamSpirit';
all_from 'lib/WebService/TeamSpirit.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
