package Data::Bahe::ForTerm;

# AUTHORITY
# DATE
# DIST
# VERSION

use Role::Tiny;
use Role::Tiny::With;

use Color::ANSI::Util qw(ansifg ansibg ansi_reset);

with 'Role::TinyCommons::TermAttr::Size';
requires 'get_color';

around new => sub {
    my $orig = shift;
    my $self = $orig->(@_);
    $self->{right_margin} //= $self->termattr_width;
    $self;
};

sub colorize {
    my ($self, $r, $str, $color_name) = @_;

    my $color;

    for (@{ ref $color_name eq 'ARRAY' ? $color_name : [$color_name] }) {
        $color = $self->get_color($r, $_);
        last if defined $color;
    }
    return $str unless defined $color;

    my ($fgcolor, $bgcolor);
    if (ref $color eq 'ARRAY') {
        $fgcolor = $color->[0];
        $bgcolor = $color->[1];
    } else {
        $fgcolor = $color;
    }
    my $code_start_fg = defined $fgcolor ? ansifg($fgcolor) : '';
    my $code_start_bg = defined $bgcolor ? ansibg($bgcolor) : '';
    my $code_end = length($code_start_fg) || length($code_start_bg) ?
        ansi_reset() : '';

    $code_start_fg . $code_start_bg . $str . $code_end;
}

1;
# ABSTRACT: Methods for when running in terminal

=head1 DESCRIPTION
