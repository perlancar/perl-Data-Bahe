package Data::Bahe::ColorTheme::Random;

# AUTHORITY
# DATE
# DIST
# VERSION

use Role::Tiny;

use Color::RGB::Util qw(rand_rgb_color);

sub get_color {
    my ($self, $r, $name) = @_;
    rand_rgb_color();
}

1;
# ABSTRACT: Random foreground colors all the time, just for testing

=for Pod::Coverage ^(.+)$
