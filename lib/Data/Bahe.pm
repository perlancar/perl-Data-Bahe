package Data::Bahe;

# DATE
# VERSION

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

sub dquote_str {

    local($_) = $_[0];

    # If there are many '"' we might want to use qq() instead
    s/([\\\"\@\$])/\\$1/g;
    return qq("$_") unless /[^\040-\176]/;  # fast exit

    s/([\a\b\t\n\f\r\e])/$esc{$1}/g;

    # no need for 3 digits in escape for these
    s/([\0-\037])(?!\d)/sprintf('\\%o',ord($1))/eg;

    s/([\0-\037\177-\377])/sprintf('\\x%02X',ord($1))/eg;
    s/([^\040-\176])/sprintf('\\x{%X}',ord($1))/eg;

    return qq("$_");
}

sub dump {
    my $self = shift;
}

sub pdump {
    my $self = shift;
    print $self->dump(@_);
    @_;
}

1;
# ABSTRACT: Pretty-printing of data structures

=encoding utf8

=head1 SYNOPSIS

 use Data::Bahe;

 my $bahe = Data::Bahe->new(%opts);

 # return dumped data, print nothing
 my $dump = $bahe->dump(@data);

 # print dumped data, return the original
 $bahe->pdump(@data);


=head1 DESCRIPTION

B<EARLY RELEASE, LOTS OF UNIMPLEMENTED STUFFS>.

This class is "yet another data dumper". The focus is on flexibility and nice
output (and not on speed). My goal is to be able to have features of
L<Data::Dump> (like base64- and hex-encoding, ranges, formatting),
L<Data::Dump::Color> (colors, comments to aid debugging) in a single codebase.
It should also be flexible enough to be subclassed to dump JSON/YAML, PHP (like
L<Data::Dump::PHP>), or Ruby (like L<Data::Dump::Ruby>). I also want to support
more advanced features, e.g.: highlighting some parts of data (certain escape
sequences in strings, etc), hiding some other parts of data, different brace
colors for different levels, and so on.

Of course, the basics like handling of circular references, coderefs, Regexp
objects, etc are supported.

My main use-cases are for this module are: debugging (producing colored dump
with visual aids/comments) and producing dump in POD (custom sorting of hash
keys, vertical alignment, observing right margin).

About the module name: bahé is a Sundanese word meaning "to spill out" or "to
pour" (liquid).


=head1 METHODS

=head2 new(%opts) => obj

Constructor. Known options:

=over

=back


=head2 $bahe->dump(@data) => str

Dump data.

=head2 $bahe->pdump(@data) => @data

Print dumped data and return the original result. A shortcut for:

 print $bahe->dump(@data);
 return @data;


=head1 SEE ALSO

L<Data::Dumper>

L<Data::Dump>

L<Data::Dmp>
