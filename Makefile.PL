use inc::Module::Install;
name 'Plack-App-Reproxy';
all_from 'lib/Plack/App/Reproxy.pm';

test_requires 'Test::More';
use_test_base;
author_tests('xt');

auto_include;
auto_set_repository;

WriteAll;
