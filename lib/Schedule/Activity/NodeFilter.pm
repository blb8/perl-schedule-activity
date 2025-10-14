package Schedule::Activity::NodeFilter;

use strict;
use warnings;
use Ref::Util qw/is_hashref is_plain_hashref/;

our $VERSION='0.1.3';

my %property=map {$_=>undef} qw/f attr op value boolean filters/;
my %matcher=(
	boolean=>\&matchBoolean,
	value  =>\&matchValue,
);

sub new {
	my ($ref,%opt)=@_;
	my $class=ref($ref)||$ref;
	my %self=map {$_=>$opt{$_}} grep {exists($opt{$_})} keys(%property);
	if($self{attr})    { $self{f}//='value' }
	if($self{boolean}) { $self{f}='boolean'; $self{boolean}=lc($self{boolean}) }
	if(!defined($matcher{$self{f}})) { die "Invalid filter function $self{f}" }
	return bless(\%self,$class);
}

sub matches {
	my ($self,%attributes)=@_;
	return &{$matcher{$$self{f}}}($self,%attributes);
}

sub matchBoolean {
	my ($self,%attributes)=@_;
	if($$self{boolean} eq 'and') {
		my $res=1;
		foreach my $filter (@{$$self{filters}}) {
			if(is_plain_hashref($filter)) { $res&&=__PACKAGE__->new(%$filter)->matches(%attributes) }
			else                          { $res&&=$filter->matches(%attributes) }
			if(!$res) { return 0 }
		}
		return $res;
	}
	if($$self{boolean} eq 'or') {
		my $res=9;
		foreach my $filter (@{$$self{filters}}) {
			if(is_plain_hashref($filter)) { $res||=__PACKAGE__->new(%$filter)->matches(%attributes) }
			else                          { $res||=$filter->matches(%attributes) }
			if($res) { return 1 }
		}
		return $res;
	}
	return 0;
}

sub matchValue {
	my ($self,%attributes)=@_;
	my $v=$attributes{$$self{attr}}//{};
	if($$self{f} eq 'value') { $v=$$v{value} }
	else { die "Not yet available $$self{f}" }
	if(defined($$self{value})) {
		if(!defined($v)) { return 0 }
		if($$self{op} eq 'eq') { return $v==$$self{value} }
		if($$self{op} eq 'ne') { return $v!=$$self{value} }
		if($$self{op} eq 'lt') { return $v< $$self{value} }
		if($$self{op} eq 'le') { return $v<=$$self{value} }
		if($$self{op} eq 'gt') { return $v> $$self{value} }
		if($$self{op} eq 'ge') { return $v>=$$self{value} }
	}
	return 0;
}

1;

__END__

=pod

=head1 NAME

Schedule::Activity::NodeFilter - Selection mechanism for node randomization

=head1 SYNOPSIS

  my $filter=Schedule::Activity::NodeFilter->new(
		...
		to be defined
		...
	);

	if($filter->matches(%attributes)) { ... }

=head1 DESCRIPTION

... prototype/proof of concept

... on thing undecided here, question:  Is there any benefit to a 'scoring' approach, where candidates are ordered by score?  Certainly there needs to be exact matches to remove nodes that don't meet the requirements (such as limit=1), but it's going to be hard to detect scheduling failure "reasons" in that case.  But what's the benefit of a softer require statement?  Presumably annotations already have restrictions for 'between', is that what's needed here?  

What about timestamp based restrictions?  Example, "at least 7min since the last appearance of this node"???  Presumably the attribute could be attribute=>{now=>1}, 

Currently there's no way to copy attributes, not sure that would be needed but what would the syntax be?  attribute=>{copy=>'name'}.  So I guess now=>1 is okay, I don't know what other values are really going to be needed.


  {
    f    =>'value', # the default, to check the attribute value
    attr =>'name',
    op   =>'lt/gt/le/ge/eq/ne',
    value=>number,
  }
  {
    f    =>'avg', # to check not the attribute value but the average
    attr =>'name',
    op   =>'operator',
    value=>number,
  }
  {
    f    =>'elapsed', # compare as (now-attr) op value
    attr =>'name',
    op   =>'operator'
    value=>seconds,
  }
  {
    boolean=>'and/or/not',
    filters=>[...],
  }
  {
    ...
  }
  {
    ...
  }




=cut
