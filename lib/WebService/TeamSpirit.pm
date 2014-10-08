package WebService::TeamSpirit;

=encoding utf8

=head1 NAME

  WebService::TeamSpirit - teamspirit.cloudforce.com client for perl.

=head1 SYNOPSIS

  use WebService::TeamSpirit;
  my $ts = WebService::TeamSpirit->new(
    email    => 'your email', #require if you login
    password => 'your password', #require if you login
  );

  $ts->login(); #if you login
  my $tl = $ts->friends_timeline();
  for my $row (@$tl){
    warn YAML::Dump $row;
  }

=head1 DESCRIPTION

  WebService::TeamSpirit is scraping library client for perl at teamspirit.cloudforce.com

=cut

use strict;
use warnings;
use utf8;
use Carp;
use Encode;
use JSON::XS qw/encode_json decode_json/;
use HTTP::Date;
use Try::Tiny;
use URI;
use Web::Scraper;
use WWW::Mechanize;
use YAML;

our $VERSION = '0.01';

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new teamspirit.cloudforce.com object.

  my $lingr = WebService::TeamSpirit->new(
      email =>    q{teamspirit login email},
      password => q{teamspirit password},
  );

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my $self = bless { %args }, $class;

    $self->{last_req} ||= time;
    $self->{interval} ||= 1;

    $self->mech();
    return $self;
}

=head1 Accessor

=over

=item B<mech>

  WWW::Mechanize object.

=cut

sub mech {
    my $self = shift;
    unless($self->{mech}){
        my $mech = WWW::Mechanize->new(
            agent      => 'Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0',
            cookie_jar => {},
        );
        $mech->stack_depth(10);
        $self->{mech} = $mech;
    }
    return $self->{mech};
}

=item B<interval>

sleeping time per one action by Mech.

=item B<last_request_time>

request time at last;

=item B<last_content>

cache at last decoded content.

=cut

sub interval          { return shift->{interval} ||= 1    }
sub last_request_time { return shift->{last_req} ||= time }

sub last_content {
    my $self = shift;
    my $arg  = shift || '';

    if($arg){
        $self->{last_content} = $arg
    }
    return $self->{last_content} || '';
}

=item B<base_url>

=cut

sub base_url {
    my $self = shift;
    my $arg  = shift || '';

    if($arg){
        $self->{base_url} = $arg;
        $self->{conf}     = undef;
    }
    return $self->{base_url} || 'https://teamspirit.cloudforce.com';
}

=back

=head1 METHODS

=head2 set_last_request_time

set request time

=cut

sub set_last_request_time { shift->{last_req} = time }


=head2 post

mech post with interval.

=cut

sub post {
    my $self = shift;
    $self->_sleep_interval;
    my $res = $self->mech->post(@_);
    return $self->_content($res);
}

=head2 get

mech get with interval.

=cut

sub get {
    my $self = shift;
    $self->_sleep_interval;
    my $res = $self->mech->get(@_);
    return $self->_content($res);
}

=head2 conf

  url path config

=cut

sub conf {
    my $self = shift;
    unless ($self->{conf}){
        my $base_url =  $self->base_url();
        my $conf = {
            enter   =>      sprintf("%s/",                                $base_url),
            say     =>      sprintf("%s/chatter/handlers/feeditems",      $base_url),
            home    =>      sprintf("%s/home/home.jsp",                   $base_url),
            chatter =>      sprintf("%s/_ui/core/chatter/ui/ChatterPage", $base_url),
            chatter_more => sprintf("%s/chatter/handlers/feed",           $base_url),
        };
        $self->{conf} = $conf;
    }
    return $self->{conf};
}

=head2 login

  sign in at teamspirit.cloudforce.com

=cut

sub login {
    my $self = shift;

    {
        my $params = {
            un             => $self->{email},
            width          => 1080,
            height         => 1920,
            hasRememberUn  => 'true',
            startURL       => '',
            loginURL       => '',
            loginType      => '',
            useSecure      => 'true',
            local          => '',
            lt=>           => 'standard',
            qs             => '',
            locale         => 'jp',
            oauth_token    => '',
            oauth_callback => '',
            login          => '',
            serverid       => '',
            display        => 'page',
            username       => $self->{email},
            pw             => $self->{password},
            Login          => '%E3%83%AD%E3%82%B0%E3%82%A4%E3%83%B3'
        };
        $self->post($self->conf->{enter}, $params);
    }
    if($self->last_content =~ m{((https://.*?.cloudforce.com)/home/home.jsp)}){
        my $next_url = $1;
        my $base_url = $2;
        $self->base_url($base_url);
        $self->get($next_url);
    }
    else {
        die 'cant login';
    }

    $self->get($self->conf->{home});
    if($self->last_content =~ m{(?:.*)/(.*?)/base/dCustom0\.css(.*)"}){
        $self->{user_id} = $1;
    }
    else{
        die 'cant get user_id';
    }
}

=head2 say

post content to teamspirit.cloudforce.com

=cut

sub say {
    my $self = shift;
    my $args = shift;

    my $content = {
        feedItemType       => 'TextPost',
        entityId           => $self->{user_id},
        feedItemVisibility => '',
        topicIds           => '',
        feedType           => 'NEWS',
        text               => Encode::decode_utf8($args->{content}),
    };

    try {
        $self->get($self->conf->{home});
        my $token = '';
        if($self->last_content =~ m{<script>chatter.getToolbox\(\).setToken\('(.*?)'\);</script>}){
            $token = $1;
        }
        else {
            die 'cant get token';
        }

        my $headers = {
            Authorization     => $token,
        };

        for my $key (keys %$headers ){
            $self->mech->add_header($key => $headers->{$key});
        }

        $self->post($self->conf->{say}, $content);

        for my $key (keys %$headers ){
            $self->mech->delete_header($key);
        }
    }
    catch {
        my $e = $_;
        warn $e;
    };
}

=head2 friends_timeline

chatter の発言もってくる

=cut

sub friends_timeline {
    my $self = shift;
    my $args = shift || {};
    my $page = 1; #$args->{page} || 1;
    $self->get($self->conf->{chatter});

    my $tl   = [];
    my $html = $self->last_content;
    push @$tl, @{ $self->_parse_tl($self->last_content()) };

    for(2..$page){

        my $url            = URI->new(sprintf("%s/%s/NEWS", $self->conf->{chatter_more}, $self->{user_id}));
        my $next_feed_item = $self->_get_next_feed_item($html);
        $url->query_form({
                _dc             => time() . 000,
                paginationToken => $next_feed_item,
                writable        => 'ReadWrite',
                feedfilter      => 'all',
                keyprefix       => '',
        });
        my $path = $url->as_string;
        my $token;
        {
            $self->get($self->conf->{chatter});
            if($self->last_content() =~ m{<script>chatter.getToolbox\(\).setToken\('(.*?)'\);</script>}){
                $token = $1;
            }
        }

        my $headers = {
            Authorization     => $token,
        };

        for my $key (keys %$headers ){
            $self->mech->add_header($key => $headers->{$key});
        }

        $self->get($path);

        for my $key (keys %$headers ){
            $self->mech->delete_header($key);
        }
        my $json   = $self->last_content();
        $json      =~ s{^while\(1\);\n}{}; #jsonなのに何か頭に余計なのついてるから除去
        my $struct = decode_json($json);
        $html   = $struct->{html};
        push @$tl, @{ $self->_parse_tl($html) };
    }
    return $tl;
}

=head1 PRIVATE METHODS.

=over

=item B<_get_next_feed_item>

=cut
sub _get_next_feed_item {
    my $self = shift;
    my $html = shift;
    my $scraper = scraper {
        process '//div[@class="cxshowmorefeeditemscontainer showmorefeeditemscontainer"]/a', mfs  => '@onclick';
        result 'mfs';
    };
    my $result = $scraper->scrape($html);
    # chatter.getFeed().showMoreFeedItems(this, {paginationToken:'2014-10-07T10:09:49Z,0D51000000oRwl8CAC'})
    # みたいな形でかえってくるので 2014-10-07T10:09:49Z,0D51000000oRwl8CAC 部分だけとる。
    return [ split(/'/, $result) ]->[1];
}

=item B<_parse_tl>

タイムラインのパース

=cut

sub _parse_tl {
    my $self = shift;
    my $html = shift;

    my $scraper = scraper {
        process '//div[@class="cxfeeditem feeditem"]', 'data[]'=> scraper {
            process '//div[@class="topics "]',                  post_id     => '@data-entityid';
            process '//span[@class="feeditemfirstentity"]',         username    => 'TEXT';
            process '//span[@class="feeditemfirstentity"]/a',       userid      => '@href';
            process '//span[@class="feeditemtext cxfeeditemtext"]', description => 'TEXT';
            process '//a[@class="feeditemtimestamp"]',              timestamp   => 'TEXT';
            process '//span[@class="collaborationGroupMru"]/img',   is_group    => '@alt';
        };
        result 'data';
    };
    my $result = $scraper->scrape($html);
    my $tl = [];
    for my $row (@$result){
        my $timestamp = $row->{timestamp};
        $timestamp    = HTTP::Date::str2time($self->_parse_date($timestamp));
        my $line = {
            userid => [ split '/', $row->{userid} ]->[1],
            description => $row->{description},
            username    => $row->{username},
            timestamp   => $timestamp,
            post_id     => $row->{post_id},
        };
        if($row->{is_group} and
           $row->{is_group} eq 'グループ'){
            $line->{is_group} = 1;
        }
        push @$tl, $line;
    }
    return $tl;
}

=item B<__parse_date>

昨日(10:10) みたいなフォーマットで出力されるので
適切な形式に直す

=cut

sub _parse_date {
    my $self      = shift;
    my $timestamp = shift;
    my $datetime  = '';
    my $date_sub = 0;
    my $no_date  = 0;


    if($timestamp =~ m{今日}){
        $timestamp =~ s{今日}{};
        $no_date = 1;
    }
    elsif($timestamp =~ m{(\d)\s日前}){
        $timestamp =~ s{(\d)\s日前}{};
        $date_sub  = $1;
        $no_date   = 1;
    }
    elsif($timestamp =~ m{昨日}){
        $timestamp =~ s{昨日}{};
        $date_sub  = 1;
        $no_date   = 1;
    }

    if($no_date){
        my $now = time();
        if($timestamp =~m{\((\d{1,2}):(\d{2})\)}){
            my ($hour, $min) =($1, $2);
            $now = $now - (60 * 60 * 24 * $date_sub);
            my (undef, undef, undef, $mday, $mon, $year,) = localtime($now);
            my $datetime = sprintf("%s-%02d-%02d %02d:%02d:00", (
                    $year+1900,
                    $mon +1,
                    $mday,
                    $hour,
                    $min
                )
            );
        }
        else{
            die 'cant parse date';
        }
    }
    else{
        $timestamp =~ s{/}{-}g;
        $timestamp =~ s{\(}{ };
        $timestamp =~ s{\)}{};
        $datetime  = $timestamp . ':00';
    }
}

=item B<_sleep_interval>

アタックにならないように前回のリクエストよりinterval秒待つ。

=cut

sub _sleep_interval {
    my $self = shift;
    my $wait = $self->interval - (time - $self->last_request_time);
    sleep $wait if $wait > 0;
    $self->set_last_request_time();
}

=item b<_content>

decode content with mech.

=cut

sub _content {
  my $self = shift;
  my $res  = shift;
  my $content = $res->decoded_content();
  $self->last_content($content);
  return $content;
}

=back

=cut

1;
__END__

likkradyus E<lt>perl {at} li.que.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
