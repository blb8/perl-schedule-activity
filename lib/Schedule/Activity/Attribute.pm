package Schedule::Activity::Attribute;

use strict;
use warnings;

our $VERSION='0.1.3';

my %types=(
	int=>{
		change =>\&_changeInt,
		average=>\&_avgInt,
		changes=>{map {$_=>undef} qw/type value set incr decr tm note/},
	},
	bool=>{
		change =>\&_changeBool,
		average=>\&_avgBool,
		changes=>{map {$_=>undef} qw/type value set tm note/},
	},
);

sub new {
	my ($ref,%opt)=@_;
	my $class=ref($ref)||$ref;
	my %self=(
		type =>$opt{type}//'int',
		value=>$opt{value}//0,
		log  =>{},
		tmmax=>$opt{tm}//0,
	);
	if(!defined($types{$self{type}})) { die "Attribute invalid type:  $self{type}" }
	$self{log}{$opt{tm}//0}=$self{value};
	return bless(\%self,$class);
}

sub validateConfig {
	my ($self,%opt)=@_;
	my $C=$types{$$self{type}}{changes};
	my @errors=grep {!exists($$C{$_})} keys %opt;
	if(@errors) { return "Invalid attribute options/commands:  ".join(' ',@errors) }
	return;
}

sub log {
	my ($self,$tm)=@_;
	if(defined($tm)&&($tm>=$$self{tmmax})) { $$self{log}{$tm}=$$self{value}; $$self{tmmax}=$tm }
	return $self;
}

sub change {
	my ($self,%opt)=@_;
	my $tm=$opt{tm}//$$self{tmmax};
	if($tm<$$self{tmmax}) { return $self }
	&{$types{$$self{type}}{change}}($self,%opt);
	$self->log($tm); # updates tmmax
	return $self;
}

sub report {
	my ($self)=@_;
	return (
		y  =>$$self{value},
		xy =>[$self->_xy()],
		avg=>$self->average(),
	);
}

sub value {
	my ($self)=@_;
	if($$self{type} eq 'int')  { return 0+$$self{value} }
	if($$self{type} eq 'bool') { return !!$$self{value} }
}

sub average {
	my ($self)=@_;
	return &{$types{$$self{type}}{average}}($$self{log});
}

sub _xy {
	my ($self)=@_;
	return map {[$_,$$self{log}{$_}]} sort {$a<=>$b} keys %{$$self{log}};
}

# set=>value
# incr=>value
# decr=>value
# tm=>tm # optional, will create a log entry
sub _changeInt {
	my ($self,%opt)=@_;
	if(defined($opt{set})) { $$self{value}=$opt{set} }
	if($opt{incr})         { $$self{value}+=$opt{incr} }
	if($opt{decr})         { $$self{value}-=$opt{decr} }
	return $self;
}

# set=>value
# tm=>tm # optional, will create a log entry
sub _changeBool {
	my ($self,%opt)=@_;
	if(defined($opt{set})) { $$self{value}=$opt{set} }
	return $self;
}

sub _avgInt {
	my ($log)=@_;
	my ($avg,$weight,$lasttm,$lasty)=(0,0);
	foreach my $tm (sort {$a<=>$b} keys(%$log)) {
		if(!defined($lasttm)) { ($lasttm,$lasty)=($tm,$$log{$tm}); next }
		my $dt=$tm-$lasttm;
		$avg=$weight/($weight+$dt)*$avg+0.5*$dt/($weight+$dt)*($lasty+$$log{$tm});
		$weight+=$dt;
		$lasttm=$tm;
		$lasty=$$log{$tm};
	}
	return $avg;
}

sub _avgBool {
	my ($log)=@_;
	my ($sum,$weight,$lasttm,$lasty)=(0,0);
	foreach my $tm (sort {$a<=>$b} keys(%$log)) {
		if(!defined($lasttm)) { ($lasttm,$lasty)=($tm,$$log{$tm}); next }
		my $dt=$tm-$lasttm;
		$sum+=$lasty*($tm-$lasttm);
		$weight+=$dt;
		$lasttm=$tm;
		$lasty=$$log{$tm};
	}
	return $sum/$weight;
}

1;

__END__

=pod

=head1 NAME

Schedule::Activity::Attribute - Updating, tracking, and reporting numeric values.

=head1 SYNOPSIS

  my $attr=Schedule::Activity::Attribute->new(type=>'int',value=>0,tm=>0);
  $attr->change(tm=>10,set=>10);
  $attr->change(tm=>20,set=>20);
  print $attr->value();
  print $attr->average();

=head1 DESCRIPTION

This module is responsible for individual attributes.  It tracks values for the attribute, facilitates updates, and handles reporting.

Attributes are intended to be I<typed>, so cross-type requests may produce failures.

=head1 Functions

=head2 change

Ideally called as C<$attr->change(tm=>tm,options)>, this updates the value of the attribute and logs at the given timestamp.  Change options must be type-appropriate.  The specified time must exceed (or be the same as) the maximum logged time for the attribute to have any effect.  That is, historical values don't update the current value, nor do they create an entry in the log.

Called without a timestamp, the maximum time will be assumed, the value changed, and the logged entry overwritten.

Historic entry is proposed by not yet defined, since it must support C<set> and C<incr> options.

=head2 value

The value of the attribute associated with the logged event having the maximum time.

=head2 average

Computes the type-specific time-weighted "average value" over all entries in the log.  Currently this is a heavy action that requires recalculation for each call, making it accurate but slow.

=head2 report

Returns a hash of

  y    the value
  xy   this list of logged (time,value)
  avg  the time-weighted average

=head2 C<_xy>

An internal helper to build the list of values from the log.

=head2 validateConfig

Returns errors if any of the keys in an attribute configuration are unavailable for the type.  By default, the type is 'int'.

=head2 log

Called with a timestamp as C<$attr->log(tm)> to create a log entry of the current value.  This is public so callers can establish a "checkpoint" where the value is known/unchanged, typically at boundaries of events or scheduling windows.

Does nothing if the indicated time is below the maximum logged time.

=cut
