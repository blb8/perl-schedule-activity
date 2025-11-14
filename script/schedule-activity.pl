#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use JSON::XS qw/decode_json/;
use Pod::Usage;
use Storable qw/dclone/;
use Schedule::Activity;

sub load {
	my ($fn)=@_;
	my $t;
	if(!-e $fn) { die "No such file:  $fn" }
	open(my $fh,'<',$fn) or die "Unable to read configuration from $fn:  $@";
	{local($/); $t=<$fh>};
	close($fh);
	return $t;
}

sub loadeval {
	my ($fn)=@_;
	my $t=load($fn);
	$t=~s/^\s*[\%\$]?[A-Za-z_]\w+\s*=\s*//s;
	my %res;
	if($t=~/^[(]/)    { eval "\%res=$t;";       if($@) { die "$@" } } # )
	elsif($t=~/^[{]/) { eval "\%res=\%{ $t };"; if($@) { die "$@" } } # }
	else              { die "$fn does not contain a valid configuration" }
	return %res;
}

sub loadafter {
	my ($fn)=@_;
	my $t=load($fn);
	my $previous;
	eval $t;
	if($@) { die "Loading after file failed:  $@" }
	return %$previous;
}

sub saveafter {
	my ($fn,$config,$schedule)=@_;
	open(my $fh,'>',$fn);
	print $fh Data::Dumper->new([{configuration=>$config,schedule=>$schedule}],['previous'])->Indent(0)->Purity(1)->Dump();
	close($fh);
}

sub loadjson {
	my ($fn)=@_;
	my $t=load($fn);
	my %res=%{ decode_json($t) };
	return %res;
}

sub materialize {
	my (%schedule)=@_;
	my @materialized;
	foreach my $entry (@{$schedule{activities}}) {
		my $tm=int(0.5+$$entry[0]);
		if($$entry[1]{message}) {
			push @materialized,[
				sprintf('%02d:%02d:%02d'
					,int($tm/3600)
					,int(($tm%3600)/60)
					,($tm%60))
				,$$entry[1]{message}
			];
		}
	}
	foreach my $entry (@materialized) { print join(' ',@$entry),"\n" }
}

my %opt=(
	schedule  =>undef,
	json      =>undef,
	unsafe    =>undef,
	check     =>undef,
	help      =>0,
	activity  =>[],
	activities=>undef,
	notemerge =>1,
	noteorder =>undef,
	tslack    =>undef,
	tbuffer   =>undef,
	after     =>undef,
	save      =>undef,
);

GetOptions(
	'schedule=s'  =>\$opt{schedule},
	'json=s'      =>\$opt{json},
	'check'       =>\$opt{check},
	'unsafe!'     =>\$opt{unsafe},
	'activity=s'  =>\@{$opt{activity}},
	'activities=s'=>\$opt{activities},
	'notemerge!'  =>\$opt{notemerge},
	'noteorder=s' =>\$opt{noteorder},
	'tslack=f'    =>\$opt{tslack},
	'tbuffer=f'   =>\$opt{tbuffer},
	'after=s'     =>\$opt{after},
	'save=s'      =>\$opt{save},
	'help'        =>\$opt{help},
);
if($opt{help}) { pod2usage(-verbose=>1,-exitval=>2) }

my (%configuration,%after);
if($opt{after}) {
	%after=loadafter($opt{after});
	%configuration=%{$after{configuration}};
	%after=(after=>$after{schedule});
}
else { %configuration=
	$opt{schedule} ? loadeval($opt{schedule}) :
	$opt{json}     ? loadjson($opt{json}) :
	die 'Configuration is required';
}

my $scheduler=Schedule::Activity->new(unsafe=>$opt{unsafe},configuration=>\%configuration);
my %check=$scheduler->compile();
if($opt{check}) {
	if($check{error}) { print STDERR join("\n",@{$check{error}}),"\n"; exit(@{$check{error}}?1:0) }
	exit(0);
}

if($opt{activities}) { foreach my $pair (split(/;/,$opt{activities})) { push @{$opt{activity}},$pair } }
if(!@{$opt{activity}}&&!$opt{after}) { die 'Activities are required' }
for(my $i=0;$i<=$#{$opt{activity}};$i++) { $opt{activity}[$i]=[split(/,/,$opt{activity}[$i],2)] }

my %schedule=$scheduler->schedule(%after,activities=>$opt{activity},tensionslack=>$opt{tslack},tensionbuffer=>$opt{tbuffer});
if($schedule{error}) { print STDERR join("\n",@{$schedule{error}}),"\n"; exit(1) }

# Workaround.  Until other options are available, annotations canNOT be
# materialized into the activity schedule.  Such nodes are unexpected
# during subsequent annotation runs, and will need to be stashed/restored
# if we want to support saving annotations incrementally.
if($opt{save}) { $opt{notemerge}=0; saveafter($opt{save},\%configuration,\%schedule) }

if($opt{notemerge}) {
	my %seen;
	my @order;
	if($opt{noteorder}) { @order=split(/;/,$opt{noteorder}) }
	else                { @order=sort {$a cmp $b} keys(%{$schedule{annotations}}) }
	foreach my $group (@order) {
		if($seen{$group}) { next }
		if(!defined($schedule{annotations}{$group})) { next }
		push @{$schedule{activities}},@{$schedule{annotations}{$group}{events}};
		$seen{$group}=1;
	}
	if(%seen) { @{$schedule{activities}}=sort {$$a[0]<=>$$b[0]} @{$schedule{activities}} }
}

materialize(%schedule);

__END__

=pod

=head1 NAME

schedule-activity.pl - Build activity schedules.

=head1 SYNOPSIS

  schedule-activity.pl [options] configuration activities

    configuration:  [--schedule=file | --json=file]
    activities:     [--activity=time,name ... | --activities='time,name;time,name;...']

The C<--schedule> file should be a non-cyclic Perl evaluable hash or hash reference.  A C<--json> file should be a hash reference.  The format of the schedule configuration is described in L<Schedule::Activity>.

=head1 OPTIONS

=head2 --check

Compile the schedule and report any errors.

=head2 --tslack=I<number> and --tbuffer=I<number>

Set the slack or buffer tension.  Values should be from 0.0 to 1.0.

=head2 --noteorder=name;name;...

Only merge the annotation groups specified by the names.  Default is all, alphabetical.

=head2 --nonotemerge

Do not merge annotation messages into the final schedule.

=head2 --unsafe

Skip safety checks, allowing the schedule to contain cycles, non-terminating nodes, etcetera.  Useful during debugging and development.

=head1 NOTES

Unhandled failures in C<Schedule::Activity> are not trapped.  This script may die, and may run unbounded if the schedule contains infinite cycles.

=cut
