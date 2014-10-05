# Copyright (c) 2014  Timm Murray
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, 
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright 
#       notice, this list of conditions and the following disclaimer in the 
#       documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
package Device::WebIO::RaspberryPi;
$Device::WebIO::RaspberryPi::VERSION = '0.003';
# ABSTRACT: Device::WebIO implementation for the Rapsberry Pi
use v5.12;
use Moo;
use namespace::clean;
use HiPi::Wiring qw( :wiring );

use constant {
    TYPE_REV1         => 0,
    TYPE_REV2         => 1,
    TYPE_MODEL_B_PLUS => 2,
};

use constant {
    # maps of Rpi Pin -> Wiring lib pin
    PIN_MAP_REV1 => {
        0  => 8,
        1  => 9,
        4  => 7,
        7  => 11,
        8  => 10,
        9  => 13,
        10 => 12,
        11 => 14,
        14 => 15,
        15 => 16,
        17 => 0,
        18 => 1,
        21 => 2,
        22 => 3,
        23 => 4,
        24 => 5,
        25 => 6,
    },
    PIN_MAP_REV2 => {
        2  => 8,
        3  => 9,
        4  => 7,
        7  => 11,
        8  => 10,
        9  => 13,
        10 => 12,
        11 => 14,
        14 => 15,
        15 => 16,
        17 => 0,
        18 => 1,
        27 => 2,
        28 => 17,
        22 => 3,
        23 => 4,
        24 => 5,
        25 => 6,
        30 => 19,
        29 => 18,
        31 => 20,
    },
    PIN_MAP_MODEL_B_PLUS => {
        2  => 8,
        3  => 9,
        4  => 7,
        7  => 11,
        8  => 10,
        9  => 13,
        10 => 12,
        11 => 14,
        14 => 15,
        15 => 16,
        17 => 0,
        18 => 1,
        27 => 2,
        28 => 17,
        22 => 3,
        23 => 4,
        24 => 5,
        25 => 6,
        30 => 19,
        29 => 18,
        31 => 20,
    },
};

has 'pin_desc', is => 'ro';
has '_type',    is => 'ro';
has '_pin_mode' => (
    is => 'ro',
);
has '_pin_map' => (
    is => 'ro',
);
# Note that _output_pin_value should be mapped by the Wiring library's 
# pin number, *not* the Rpi's numbering
has '_output_pin_value' => (
    is => 'ro',
);


my $CALLED_WIRING_SETUP = 0;


sub BUILDARGS
{
    my ($class, $args) = @_;
    my $rpi_type = delete($args->{type}) // $class->TYPE_REV1;

    $args->{pwm_bit_resolution} = 10;
    $args->{pwm_max_int}        = 2 ** $args->{pwm_bit_resolution};

    if( TYPE_REV1 == $rpi_type ) {
        $args->{input_pin_count}  = 26;
        $args->{output_pin_count} = 26;
        $args->{pwm_pin_count}    = 0;
        $args->{pin_desc}         = $class->_pin_desc_rev1;
        $args->{'_pin_map'}       = $class->PIN_MAP_REV1;
    }
    elsif( TYPE_REV2 == $rpi_type ) {
        $args->{input_pin_count}  = 26;
        $args->{output_pin_count} = 26;
        $args->{pwm_pin_count}    = 1;
        $args->{pin_desc}         = $class->_pin_desc_rev2;
        $args->{'_pin_map'}       = $class->PIN_MAP_REV2;
    }
    elsif( TYPE_MODEL_B_PLUS == $rpi_type ) {
        $args->{input_pin_count}  = 26;
        $args->{output_pin_count} = 26;
        $args->{pwm_pin_count}    = 1;
        $args->{pin_desc}         = $class->_pin_desc_model_b_plus;
        $args->{'_pin_map'}       = $class->PIN_MAP_MODEL_B_PLUS;
    }
    else {
        die "Don't know what to do with Rpi type '$rpi_type'\n";
    }

    $args->{'_pin_mode'}         = [ ('IN') x $args->{input_pin_count}  ];
    $args->{'_output_pin_value'} = [ (0)    x $args->{output_pin_count} ];

    HiPi::Wiring::wiringPiSetup() unless $CALLED_WIRING_SETUP;
    $CALLED_WIRING_SETUP = 1;

    return $args;
}


has 'input_pin_count', is => 'ro';
with 'Device::WebIO::Device::DigitalInput';

sub set_as_input
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    $self->{'_pin_mode'}[$pin] = 'IN';
    HiPi::Wiring::pinMode( $pin, WPI_INPUT );
    return 1;
}

sub input_pin
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    my $in = HiPi::Wiring::digitalRead( $pin );
    return $in;
}

sub is_set_input
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    return 1 if $self->_pin_mode->[$pin] eq 'IN';
    return 0;
}


has 'output_pin_count', is => 'ro';
with 'Device::WebIO::Device::DigitalOutput';

sub set_as_output
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    $self->{'_pin_mode'}[$pin] = 'OUT';
    HiPi::Wiring::pinMode( $pin, WPI_OUTPUT );
    return 1;
}

sub output_pin
{
    my ($self, $rpi_pin, $value) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    $self->_output_pin_value->[$rpi_pin] = $value;
    HiPi::Wiring::digitalWrite( $pin, $value ? WPI_HIGH : WPI_LOW );
    return 1;
}

sub is_set_output
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
    return undef if $pin < 0;
    return 1 if $self->_pin_mode->[$pin] eq 'OUT';
    return 0;
}


has 'pwm_pin_count',      is => 'ro';
has 'pwm_bit_resolution', is => 'ro';
has 'pwm_max_int',        is => 'ro';
with 'Device::WebIO::Device::PWM';

{
    my %did_set_pwm;
    sub pwm_output_int
    {
        my ($self, $rpi_pin, $val) = @_;
        my $pin = $self->_rpi_pin_to_wiring( $rpi_pin );
        return undef if $pin < 0;
        HiPi::Wiring::pinMode( $pin, WPI_PWM_OUTPUT )
            if ! exists $did_set_pwm{$pin};
        $did_set_pwm{$pin} = 1;

        HiPi::Wiring::pwmWrite( $pin, $val );
        return 1;
    }
}

has '_img_width' => (
    is      => 'rw',
    default => sub {[
        1024
    ]},
);
has '_img_height' => (
    is      => 'rw',
    default => sub {[
        768
    ]},
);
with 'Device::WebIO::Device::StillImageOutput';

my %IMG_CONTENT_TYPES = (
    'image/jpeg' => 'jpeg',
    'image/gif'  => 'gif',
    'image/png'  => 'png',
);

sub img_width
{
    my ($self, $channel) = @_;
    return $self->_img_width->[$channel];
}

sub img_height
{
    my ($self, $channel) = @_;
    return $self->_img_height->[$channel];
}

sub img_set_width
{
    my ($self, $channel, $width) = @_;
    $self->_img_width->[$channel] = $width;
    return 1;
}

sub img_set_height
{
    my ($self, $channel, $height) = @_;
    $self->_img_height->[$channel] = $height;
    return 1;
}

sub img_channels
{
    my ($self) = @_;
    return 1;
}

sub img_allowed_content_types
{
    my ($self) = @_;
    return [ keys %IMG_CONTENT_TYPES ];
}

sub img_stream
{
    my ($self, $channel, $mime_type) = @_;
    my $imager_type = $IMG_CONTENT_TYPES{$mime_type};

    my $width  = $self->img_width( $channel );
    my $height = $self->img_height( $channel );

    # TODO Capture using a more direct way than executing raspistill
    open( my $in, '-|', "raspistill -o - -w $width -h $height" ) 
        or die "Couldn't execute raspistill: $!\n";
    return $in;
}


sub _pin_desc_rev1
{
    return [qw{
        V33 V50 2 V50 3 GND 4 14 GND 15 17 18 27 GND 22 23 V33 24 10 GND 9 25
        11 8 GND 7
    }];
}

sub _pin_desc_rev2
{
    return [qw{
        V33 V50 2 V50 3 GND 4 14 GND 15 17 18 27 GND 22 23 V33 24 10 GND 9 25
        11 8 GND 7
    }];
}

sub _pin_desc_model_b_plus
{
    return [qw{
        V33 V50 2 V50 3 GND 4 14 GND 15 17 18 27 GND 22 23 V33 24 10 GND 9 25
        11 8 GND 7 GND GND 5 GND 6 12 13 GND 19 16 26 20 GND 21
    }];
}


sub _rpi_pin_to_wiring
{
    my ($self, $rpi_pin) = @_;
    my $pin = $self->_pin_map->{$rpi_pin} // -1;
    return $pin;
}


sub all_desc
{
    my ($self) = @_;
    my $pin_count = $self->input_pin_count;

    my %data = (
        UART    => 0,
        SPI     => 0,
        I2C     => 0,
        ONEWIRE => 0,
        GPIO => {
            map {
                my $function = $self->is_set_input( $_ ) ? 'IN'
                    : $self->is_set_output( $_ )         ? 'OUT'
                    : 'UNSET';
                my $value = $function eq 'IN'
                    ? $self->input_pin( $_ ) 
                    : $self->_output_pin_value->[$_];
                (defined $value)
                    ? (
                        $_ => {
                            function => $function,
                            value    => $value,
                        }
                    )
                    : ();
            } 0 .. ($pin_count - 1)
        },
    );

    return \%data;
}


# TODO
#with 'Device::WebIO::Device::SPI';
#with 'Device::WebIO::Device::I2C';
#with 'Device::WebIO::Device::Serial';
#with 'Device::WebIO::Device::VideoStream';

1;
__END__


=head1 NAME

  Device::WebIO::RaspberyPi - Access RaspberryPi pins via Device::WebIO

=head1 SYNOPSIS

    use Device::WebIO;
    use Device::WebIO::RaspberryPi;
    
    my $webio = Device::WebIO->new;
    my $rpi = Device::WebIO::RaspberryPi->new({
    });
    $webio->register( 'foo', $rpi );
    
    my $value = $webio->digital_input( 'foo', 0 );

=head1 DESCRIPTION

Access the Raspberry Pi's pins using Device::WebIO.

After registering this with the main Device::WebIO object, you shouldn't need 
to access anything in the Rpi object.  All access should go through the 
WebIO object.

=head1 IMPLEMENTED ROLES

=over 4

=item * DigitalOutput

=item * DigitalInput

=item * PWM

=item * StillImageOutput

=back

=head1 LICENSE

Copyright (c) 2014  Timm Murray
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are 
permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of 
      conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of
      conditions and the following disclaimer in the documentation and/or other materials 
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS 
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR 
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
