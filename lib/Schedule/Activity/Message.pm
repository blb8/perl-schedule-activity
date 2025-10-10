package Schedule::Activity::Message;

use strict;
use warnings;
use Ref::Util qw/is_arrayref is_hashref is_ref/;

our $VERSION='0.1.1';

my %property=map {$_=>undef} qw/message attributes note/;

sub new {
	my ($ref,%opt)=@_;
	my $class=ref($ref)||$ref;
	my %self=(
		attributes=>$opt{attributes}//{},
		msg       =>[],
	);
	if(is_hashref($opt{message})&&is_arrayref($opt{message}{alternates})) { @{$self{msg}}=grep {is_hashref($_) && !is_ref($$_{message}) && defined($$_{message})} @{$opt{message}{alternates}} }
	elsif(is_arrayref($opt{message})) { @{$self{msg}}=grep {!is_ref($_) && defined($_)} @{$opt{message}} }
	elsif(!is_ref($opt{message}))     { @{$self{msg}}=grep {!is_ref($_) && defined($_)} $opt{message} }
	return bless(\%self,$class);
}

sub unwrap {
	my ($self,$msg)=@_;
	if(!defined($msg)) { return ('',$self) }
	if(!is_ref($msg))  { return ($msg,$self) }
	if(is_hashref($msg)) { return ($$msg{message},$msg) }
	return ('',$msg);
}

sub primary { my ($self)=@_; return $self->unwrap($$self{msg}[0]) }
sub random  { my ($self)=@_; return $self->unwrap($$self{msg}[ int(rand(1+$#{$$self{msg}})) ]) }

sub attributesFromConf {
	my ($conf)=@_;
	if(!is_hashref($conf)) { return }
	my @res;
	if(is_hashref($$conf{attributes})) {
		while(my ($k,$v)=each %{$$conf{attributes}}) { push @res,[$k,$v] } }
	if(is_arrayref($$conf{alternates})) {
		foreach my $message (grep {is_hashref($_)} @{$$conf{alternates}}) {
			if(is_hashref($$message{attributes})) {
				while(my ($k,$v)=each %{$$message{attributes}}) { push @res,[$k,$v] } } } }
	return @res;
}

1;

__END__

=pod

=head1 NAME

Schedule::Activity::Message - Container for individual or multiple messages

=head1 SYNOPSIS

	my $message=Schedule::Activity::Message->new(
		message   =>'string message',
		message   =>['array', 'of', 'alternates'],
		message   =>{
			alternates=>[
				{message=>'string', attributes=>{...}},
				{message=>'string', attributes=>{...}},
				...
			],
		}
		attributes=>{...} # optional
		note      =>...   # optional
	);

=head1 FUNCTIONS

=head2 random

Retrieve a pair of C<(message,object)>, which is either an individual string message, or a random selection from an array or hash of alternatives.  The first index will always be a string, possibly empty.  The object can be used to inspect message attributes.

=head2 attributesFromConf

Given a plain (unknown) message configuration, find any embedded attributes.  This function is primarily useful during schedule configuration validation, prior to full action nodes being built, to identify all attributes within a nested configuration.  It does not need to handle named attributes because those are separately declared.

=cut
