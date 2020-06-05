## no critic: (Modules::ProhibitAutomaticExportation)

package Data::Bahe;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(dd);
our @EXPORT_OK = qw(dump);


use Scalar::Util qw(looks_like_number blessed reftype refaddr);

sub new {
    my $class = shift;
    my %opts = @_;

    # set defaults for options
    $opts{perl_version}   //= "5.010";
    $opts{remove_pragmas} //= 0;

    bless \%opts, $class;
}

my %esc = (
    "\a" => "\\a",
    "\b" => "\\b",
    "\t" => "\\t",
    "\n" => "\\n",
    "\f" => "\\f",
    "\r" => "\\r",
    "\e" => "\\e",
);

sub dump_str {
    my ($self, $r, $val) = @_;

    # If there are many '"' we might want to use qq() instead
    $val =~ s/([\\\"\@\$])/\\$1/g;
    return qq("$_") unless $val =~ /[^\040-\176]/;  # fast exit

    $val =~ s/([\a\b\t\n\f\r\e])/$esc{$1}/g;

    # no need for 3 digits in escape for these
    $val =~ s/([\0-\037])(?!\d)/sprintf('\\%o',ord($1))/eg;

    $val =~ s/([\0-\037\177-\377])/sprintf('\\x%02X',ord($1))/eg;
    $val =~ s/([^\040-\176])/sprintf('\\x{%X}',ord($1))/eg;

    return qq("$val");
}

sub dump_code {
    my ($self, $r, $code) = @_;

    state $deparse = do {
        require B::Deparse;
        B::Deparse->new("-l"); # -i option doesn't have any effect?
    };

    my $res = $deparse->coderef2text($code);

    my ($res_before_first_line, $res_after_first_line) =
        $res =~ /(.+?)^(#line .+)/ms;

    if ($self->{remove_pragmas}) {
        $res_before_first_line = "{";
    } elsif ($self->{perl_version} < 5.016) {
        # older perls' feature.pm doesn't yet support q{no feature ':all';} so
        # we replace it with q{no feature}.
        $res_before_first_line =~ s/no feature ':all';/no feature;/m;
    }
    $res_after_first_line =~ s/^#line .+//gm;

    $res = "sub" . $res_before_first_line . $res_after_first_line;
    $res =~ s/^\s+//gm;
    $res =~ s/\n+//g;
    $res =~ s/;\}\z/}/;
    $res;
}

sub dump_value {
    my ($self, $r, $val, $subscript) = @_;

    my $ref = ref($val);
    if ($ref eq '') {
        if (!defined($val)) {
            return "undef";
        } elsif (looks_like_number($val)) {
            return $val;
        } else {
            return $self->dump_str($r, $val);
        }
    }
    my $refaddr = refaddr($val);
    $r->{subscripts}{$refaddr} //= $subscript;
    if ($r->{seen_refaddrs}{$refaddr}++) {
        push @{ $r->{fixups} }, "\$a->$subscript = \$a",
            ($r->{subscripts}{$refaddr} ? "->$r->{subscripts}{$refaddr}" : ""),
            ";";
        return "'fix'";
    }

    my $class;

    if ($ref eq 'Regexp' || $ref eq 'REGEXP') {
        require Regexp::Stringify;
        return Regexp::Stringify::stringify_regexp(
            regexp=>$val, with_qr=>1, plver=>$self->{perl_version});
    }

    if (blessed $val) {
        $class = $ref;
        $ref = reftype($val);
    }

    my $res;
    if ($ref eq 'ARRAY') {
        $res = "[";
        my $i = 0;
        for (@$val) {
            $res .= "," if $i;
            $res .= $self->dump_value($r, $_, "$subscript\[$i]");
            $i++;
        }
        $res .= "]";
    } elsif ($ref eq 'HASH') {
        $res = "{";
        my $i = 0;
        for (sort keys %$val) {
            $res .= "," if $i++;
            my $k = /\W/ ? $self->dump_str($r, $_) : $_;
            my $v = $self->dump_value($r, $val->{$_}, "$subscript\{$k}");
            $res .= "$k=>$v";
        }
        $res .= "}";
    } elsif ($ref eq 'SCALAR') {
        $res = "\\".$self->dump_value($r, $$val, $subscript);
    } elsif ($ref eq 'REF') {
        $res = "\\".$self->dump_value($r, $$val, $subscript);
    } elsif ($ref eq 'CODE') {
        $res = $self->dump_code($r, $val);
    } else {
        die "Sorry, I can't dump $val (ref=$ref) yet";
    }

    $res = "bless($res, ".$self->dump_str($r, $class).")" if defined($class);
    $res;
}

sub do_dump {
    my $self = shift;

    # this is the stash (hash) variable that stores states during dumping, and
    # is passed around between the methods.
    my $r = {
        seen_refaddrs => {},
        subscripts => {},
        fixups => [],
    };


    my $res;
    if (@_ > 1) {
        $res = "(" . join(", ", map {$self->dump_value($r, $_, '')} @_) . ")";
    } elsif (@_ == 1) {
        $res = $self->dump_value($r, $_[0], '');
    } else {
        $res = undef;
    }

    if (@{ $r->{fixups} }) {
        $res = "do { my \$a=$res; " . join("", @{ $r->{fixups} }) . "\$a }";
    }
    $res;
}

# function
sub dump {
    my $opts = {};
    if (defined $ENV{PERL_BAHE_OPTS}) {
        require JSON::MaybeXS;
        $opts = JSON::MaybeXS::decode_json($ENV{PERL_BAHE_OPTS});
    }
    my $bahe = __PACKAGE__->new(%$opts);
    $bahe->do_dump(@_);
}

# function
sub dd {
    my $dump = &dump(@_);
    print $dump, ($dump =~ /\R\z/ ? "" : "\n");
    @_;
}

1;
# ABSTRACT: Pretty-printing of data structures

=for Pod::Coverage ^(do_dump|dump_.+)$

=encoding utf8

=head1 SYNOPSIS

Procedural interface:

 use Data::Bahe; # exports dd(), can export dump()

 # print dump of @data to STDOUT, with newline
 dd @data;

 # dd() can be inserted in the middle of expression because it returns the arguments.
 @data = dd foo(@args);

 sub bar {
     ...
     return dd [200,"OK",$baz];
 }

 # get the string dump of @data; you can just write dump() if you import it
 my $dump = Data::Bahe::dump(@data);

OO interface:

 use Data::Bahe (); # if you don't want to import anything

 my $bahe = Data::Bahe->new(%opts);
 my $dump = $bahe->do_dump(@data);


=head1 DESCRIPTION

B<EARLY RELEASE, LOTS OF UNIMPLEMENTED STUFFS AND UNSTABLE API>.

This class is "yet another data dumper". The focus is on flexibility and nice
output (and not on speed). My goal is to be able to have features of
L<Data::Dump> (like base64- and hex-encoding, ranges, formatting),
L<Data::Dump::Color> (colors, comments to aid debugging) in a single codebase,
and more. It should also be flexible enough to be subclassed to dump JSON/YAML,
PHP (like L<Data::Dump::PHP>), or Ruby (like L<Data::Dump::Ruby>). I also want
to support more advanced features, e.g.: highlighting some parts of data
(certain escape sequences in strings, etc), hiding some other parts of data,
different brace colors for different levels, and so on.

Of course, the basics like handling of circular references, coderefs, Regexp
objects, etc are supported.

My main use-cases are for this module are: debugging (producing colored dump
with visual aids/comments) and producing dump in POD (custom sorting of hash
keys, vertical alignment, observing right margin).

About the module name: bahé is a Sundanese word meaning "to spill out" or "to
pour" (liquid).


=head1 FUNCTIONS

=head2 dd

Usage:

 dd @data;
 my @data = dd somefunc($args); # can be inserted in the middle of expression

Exported by default. Print dump of data to STDOUT. Return the original arguments
so you can insert "dd" in the middle of expression.

=head2 dump

Usage:

 my $dump_str = dump(@data);

Not exported by default, exportable. Return the dump of data as a string. Output
nothing to STDOUT/STDERR.


=head1 METHODS

=head2 new

Constructor. Known options:

=over

=item * perl_version

=item * remove_pragmas

=back

=head2 $bahe->dump(@data) => str

Dump data.

=head2 $bahe->pdump(@data) => @data

Print dumped data and return the original result. A shortcut for:

 print $bahe->dump(@data);
 return @data;


=head1 ENVIRONMENT

=head2 PERL_BAHE_OPTS

String (encoded JSON). Set default options for the constructor. Example:

 {"remove_pragmas":true}


=head1 SEE ALSO

Other data dumpers that focus on producing nicer outputs for human:
L<Data::Dump>, L<Data::Dump::Color>, L<Data::Dumper::Compact>, L<Data::Printer>.

L<Data::Dumper>, the venerable and core module for dumping.

L<Acme::CPANModules::DumpingDataForDebugging>
