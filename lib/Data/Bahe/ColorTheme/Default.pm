package Data::Bahe::ColorTheme::Default;

# AUTHORITY
# DATE
# DIST
# VERSION

use Role::Tiny;

our %COLORS = (
    'token_paren' => undef,
    'token_brace' => undef,
    'token_comma' => undef,
    'data_undef'  => "ff0000",
);

sub get_color {
    my ($self, $r, $name) = @_;
    $COLORS{$name};
}

1;
# 256-color
