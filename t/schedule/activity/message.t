#!/usr/bin/perl

use strict;
use warnings;
use Schedule::Activity::Message;
use Test::More tests=>4;

subtest 'init'=>sub {
	plan tests=>3;
	my $msg;
	my $m='Schedule::Activity::Message';
	#
	$msg=$m->new(message=>'abcd');
	is($$msg{msg}[0],'abcd','Message:  string');
	$msg=$m->new(message=>[qw/efgh ijkl/]);
	is_deeply($$msg{msg},['efgh','ijkl'],'Message:  array');
	$msg=$m->new(message=>{
		alternates=>[
			{message=>'mnop'},
			{message=>'qrst'},
		],
	});
	is_deeply($$msg{msg},[{message=>'mnop'},{message=>'qrst'}],'Message:  hash');
};

subtest 'Primary messages'=>sub {
	plan tests=>4;
	my ($msg,$string,$href);
	my $m='Schedule::Activity::Message';
	#
	$msg=$m->new(message=>'abcd');
	($string)=$msg->primary();
	is($string,'abcd','Message:  string');
	#
	$msg=$m->new(message=>[qw/efgh ijkl/]);
	($string)=$msg->primary();
	is($string,'efgh','Message:  array');
	#
	$msg=$m->new(message=>{
		alternates=>[
			{message=>'mnop',attributes=>{one=>1}},
			{message=>'qrst',attributes=>{two=>1}},
		],
	});
	($string,$href)=$msg->primary();
	is($string,'mnop','Message:  hash');
	is_deeply($$href{attributes},{one=>1},'Message:  hash attributes');
};

subtest 'Random selection'=>sub {
	plan tests=>3;
	my ($msg,$string,%seen);
	my $m='Schedule::Activity::Message';
	#
	$msg=$m->new(message=>'abcd');
	($string)=$msg->random();
	is($string,'abcd','Message:  string');
	#
	%seen=();
	$msg=$m->new(message=>[qw/efgh ijkl/]);
	foreach (1..10) { ($string)=$msg->random(); $seen{$string}=1 }
	is_deeply(\%seen,{efgh=>1,ijkl=>1},'Message:  array');
	#
	%seen=();
	$msg=$m->new(message=>{
		alternates=>[
			{message=>'mnop',attributes=>{one=>1}},
			{message=>'qrst',attributes=>{two=>1}},
		],
	});
	foreach (1..10) { ($string)=$msg->random(); $seen{$string}=1 }
	is_deeply(\%seen,{'mnop'=>1,'qrst'=>1},'Message:  hash n=2');
};

subtest 'Attributes'=>sub {
	plan tests=>3;
	my ($message,$string,$msg,%seen);
	my $m='Schedule::Activity::Message';
	#
	$message=$m->new(message=>'hi',attributes=>{string=>{incr=>1}});
	($string,$msg)=$message->random();
	is_deeply([sort keys %{$$msg{attributes}//{}}],[qw/string/],'String message');
	#
	%seen=();
	$message=$m->new(message=>[qw/one two/],attributes=>{array=>{incr=>1}});
	foreach (1..10) {
		($string,$msg)=$message->random();
		foreach my $k (keys %{$$msg{attributes}//{}}) { $seen{$k}++ }
	}
	is_deeply(\%seen,{array=>10},'Array message');
	#
	%seen=();
	$message=$m->new(message=>
		{alternates=>[{message=>'one',attributes=>{one=>{}}},{message=>'two',attributes=>{two=>{}}}]},
		attributes=>{hash=>{incr=>1}});
	foreach (1..10) {
		($string,$msg)=$message->random();
		foreach my $k (keys %{$$msg{attributes}//{}}) { $seen{$k}++ }
	}
	is_deeply([sort keys %seen],[qw/one two/],'Hash message');
};

# attributesFromConf is effectively tested through activity.t at this point,
# but specific tests could be added to ensure that it's prevalidation safe.
