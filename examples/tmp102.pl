#!env perl
use v5.14;
use Device::WebIO;
use Device::WebIO::RaspberryPi;
use HiPi::Device::I2C ();
use constant DEVICE        => 1;
use constant SLAVE_ADDR    => 0x48;
use constant TEMP_REGISTER => 0x00;


my $webio = Device::WebIO->new;
my $rpi   = Device::WebIO::RaspberryPi->new;
$webio->register( 'rpi', $rpi );

while( 1 ) {
    my ($temp) = $webio->i2c_read( 'rpi',
        DEVICE, SLAVE_ADDR, TEMP_REGISTER, 1 );
    say 'Temp: ' . $temp . 'C';
    sleep 1;
}
