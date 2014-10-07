use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
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
my $t = <STDIN>;
chomp $t;
$ts->say({ content => $t});
