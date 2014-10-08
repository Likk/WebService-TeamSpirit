use strict;
use warnings;
use utf8;
use Test::More;

use WebService::TeamSpirit;
use Clone qw/clone/;
use DateTime;

subtest 'syntax check timestamp' => sub {

    my $ts  = WebService::TeamSpirit->new();
    my $now       = DateTime->now( time_zone => 'Asia/Tokyo');
    my $prev1     = $now->clone->add( days => -1);
    my $prev2     = $now->clone->add( days => -2);
    my $prev5     = $now->clone->add( days => -5);
    my $check_list = {
        '今日(18:48)'       => sprintf('%s %s', $now->ymd(),   '18:48:00'),
        '今日(18:08)'       => sprintf('%s %s', $now->ymd(),   '18:08:00'),
        '今日(9:59)'        => sprintf('%s %s', $now->ymd(),   '09:59:00'),
        '昨日(21:51)'       => sprintf('%s %s', $prev1->ymd(), '21:51:00'),
        '2 日前(20:43)'     => sprintf('%s %s', $prev2->ymd(), '20:43:00'),
        '5 日前(20:43)'     => sprintf('%s %s', $prev5->ymd(), '20:43:00'),
        '2014/10/03(22:00)' => sprintf('2014-10-03 %s',        '22:00:00'),
    };

    for my $key (keys %$check_list){
        is $check_list->{$key}, $ts->_parse_date($key);
    }
};

done_testing();
