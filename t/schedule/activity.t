#!/usr/bin/perl

use strict;
use warnings;
use Schedule::Activity;
use Test::More tests=>6;

subtest 'validation'=>sub {
	plan tests=>2;

	is_deeply(
		{Schedule::Activity::buildSchedule(
			configuration=>{
				node=>{
					'1'=>{
						next=>['3',[],{}],
						finish=>'4',
					},
					'2'=>{},
				},
			},
		)},{error=>['Node 1, Undefined name in array:  next']},'node:  invalid next entry');

	is_deeply(
		{Schedule::Activity::buildSchedule(
			configuration=>{
				node=>{
					'1'=>{
						next=>['2'],
						finish=>'4',
					},
					'2'=>{},
				},
			},
		)},{error=>['Node 1, Undefined name:  finish']},'node:  invalid finish entry');

};

subtest 'Simple scheduling'=>sub {
	plan tests=>5;
	my %schedule;
	my %configuration=(
		node=>{
			Activity=>{
				message=>'Begin Activity',
				next=>['action 1'],
				tmmin=>5,tmavg=>5,tmmax=>5,
				finish=>'Activity, conclude',
			},
			'action 1'=>{
				message=>'Begin action 1',
				tmmin=>5,tmavg=>10,tmmax=>15,
				next=>['action 2'],
			},
			'action 2'=>{
				message=>'Begin action 2',
				tmmin=>5,tmavg=>10,tmmax=>15,
				next=>['Activity, conclude'],
			},
			'Activity, conclude'=>{
				message=>'Conclude Activity',
				tmmin=>5,tmavg=>5,tmmax=>5,
			},
		},
	);
	%schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[30,'Activity']]);
	is_deeply(
		[map {[$$_[0],$$_[1]{message}]} @{$schedule{activities}}],
		[
			[ 0,'Begin Activity'],
			[ 5,'Begin action 1'],
			[15,'Begin action 2'],
			[25,'Conclude Activity'],
		],
		'No slack/buffer');
	%schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[32,'Activity']]);
	is_deeply(
		[map {[$$_[0],$$_[1]{message}]} @{$schedule{activities}}],
		[
			[ 0,'Begin Activity'],
			[ 5,'Begin action 1'],
			[16,'Begin action 2'],
			[27,'Conclude Activity'],
		],
		'With slack');
	%schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[40,'Activity']]);
	is_deeply(
		[map {[$$_[0],$$_[1]{message}]} @{$schedule{activities}}],
		[
			[ 0,'Begin Activity'],
			[ 5,'Begin action 1'],
			[20,'Begin action 2'],
			[35,'Conclude Activity'],
		],
		'Maximum slack');
	%schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[28,'Activity']]);
	is_deeply(
		[map {[$$_[0],$$_[1]{message}]} @{$schedule{activities}}],
		[
			[ 0,'Begin Activity'],
			[ 5,'Begin action 1'],
			[14,'Begin action 2'],
			[23,'Conclude Activity'],
		],
		'With buffer');
	%schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[20,'Activity']]);
	is_deeply(
		[map {[$$_[0],$$_[1]{message}]} @{$schedule{activities}}],
		[
			[ 0,'Begin Activity'],
			[ 5,'Begin action 1'],
			[10,'Begin action 2'],
			[15,'Conclude Activity'],
		],
		'Maximum buffer');
};

subtest 'Failures'=>sub {
	plan tests=>2;
	my %schedule;
	my %configuration=(
		node=>{
			Activity=>{
				message=>'Begin Activity',
				next=>['action 1'],
				tmmin=>5,tmavg=>5,tmmax=>5,
				finish=>'Activity, conclude',
			},
			'action 1'=>{
				message=>'Begin action 1',
				tmmin=>5,tmavg=>10,tmmax=>15,
				next=>['action 2'],
			},
			'action 2'=>{
				message=>'Begin action 2',
				tmmin=>5,tmavg=>10,tmmax=>15,
				next=>['Activity, conclude'],
			},
			'Activity, conclude'=>{
				message=>'Conclude Activity',
				tmmin=>5,tmavg=>5,tmmax=>5,
			},
		},
	);
	eval { %schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[18,'Activity']]) };
	like($@,qr/(?i:excess exceeds slack)/,'Insufficient slack');
	eval { %schedule=Schedule::Activity::buildSchedule(configuration=>\%configuration,activities=>[[42,'Activity']]) };
	like($@,qr/(?i:shortage exceeds buffer)/,'Insufficient buffer');
};

subtest 'cycles'=>sub {
	plan tests=>1;
	my %schedule;
	%schedule=Schedule::Activity::buildSchedule(activities=>[[4321,'root']],configuration=>{node=>{
		'root'=>{finish=>'terminate',next=>['cycle'],tmmin=>0,tmavg=>0,tmmax=>0},
		'cycle'=>{tmmin=>100,tmavg=>200,tmmax=>400,next=>['cycle','terminate']},
		'terminate'=>{tmmin=>0,tmavg=>0,tmmax=>0},
	}});
	ok($#{$schedule{activities}}>10,'Self-cycle');
};

subtest 'edge cases'=>sub {
	plan skip_all=>'Pending min/max reachability reporting';
	#
	# If this falls into the spin branch, it will hang.
	# Compiling/reachability should determine that the spin node can never exit, for example.
	#
	my %schedule;
	%schedule=Schedule::Activity::buildSchedule(activities=>[[3000,'root']],configuration=>{node=>{
		'root'=>{finish=>'terminate',next=>['cycle','spin'],tmmin=>0,tmavg=>0,tmmax=>0},
		'spin' =>{tmmin=>0,tmavg=>0,tmmax=>0,next=>['spin']},
		'cycle'=>{tmmin=>100,tmavg=>200,tmmax=>400,next=>['cycle','terminate']},
		'terminate'=>{tmmin=>0,tmavg=>0,tmmax=>0},
	}});
	ok($#{$schedule{activities}}>10,'Spin node');
};

subtest 'Attributes'=>sub {
	plan tests=>5;
	my $rnd=sub { my ($x)=@_; return int($x*1e6)/1e6 };
	my %schedule=Schedule::Activity::buildSchedule(activities=>[[15,'root']],configuration=>{node=>{
		root=>{
			next=>['step1'],
			tmavg=>5,
			finish=>'finish',
			attributes=>{
				counter=>{incr=>1},
				score  =>{set=>5},
				enabled=>{set=>1},
			},
		},
		'step1'=>{
			tmavg=>5,
			next=>['finish'],
			attributes=>{
				counter=>{incr=>1},
				score  =>{incr=>4},
				enabled=>{set=>0},
			},
		},
		'finish'=>{
			tmavg=>5,
			attributes=>{
				counter=>{incr=>1},
			},
		}},
		attributes=>{
			counter=>{type=>'int',value=>0},
			enabled=>{type=>'bool'},
		},
	});
	is($#{$schedule{attributes}{score}{xy}},                2,'Score:  N');
	is(&$rnd($schedule{attributes}{score}{avg}),  &$rnd(25/3),'Score:  avg');
	is($#{$schedule{attributes}{enabled}{xy}},              2,'Enabled:  N');
	is(&$rnd($schedule{attributes}{enabled}{avg}),&$rnd( 1/3),'Enabled:  avg');
	is($schedule{attributes}{counter}{y},                   3,'Counter:  count');
};

