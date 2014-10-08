use strict;
use warnings;
use utf8;
use 5.10.0;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
use Encode;
use HTTP::Date qw/time2iso/;
use WebService::TeamSpirit;

my $ts = sub { #prepare
  local $ENV{EDITOR} = 'vi';
  my $pit = pit_get('teamspirit.cloudforce.com', require => {
      email     => 'your email    on teamspirit.cloudforce.com',
      password  => 'your password on teamspirit.cloudforce.com',
    }
  );

  return WebService::TeamSpirit->new(
    %$pit
  );
}->();

my $res = $ts->login();
my $tl = $ts->friends_timeline({ page => 5 }); #5ページ前までさかのぼる // 直接5ページ前を指定することは多分無理;
for my $row (@$tl){
    # 打刻メッセージとか別に見たくない
    next if $row->{description} =~ m{^\((出社打刻|退社打刻)\)$};
    next if $row->{is_group};

    say Encode::encode_utf8(sprintf("%s %s:「%s」",
          time2iso($row->{timestamp}),
          $row->{username},
          $row->{description},
    ));
}

