package Crypt::PK::RSA;

use strict;
use warnings;

use Exporter 'import';
our %EXPORT_TAGS = ( all => [qw( rsa_encrypt rsa_decrypt rsa_sign rsa_verify )] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

use CryptX;
use Crypt::Digest;
use Carp;
use MIME::Base64 qw(encode_base64 decode_base64);

sub new { 
  my ($class, $f) = @_;
  my $self = _new();
  $self->import_key($f) if $f;
  return  $self;
}

sub export_key_pem {
  my ($self, $type) = @_;
  my $key = $self->export_key_der($type||'');
  return undef unless $key;
  
  # PKCS#1 RSAPrivateKey** (PEM header: BEGIN RSA PRIVATE KEY)
  # PKCS#8 PrivateKeyInfo* (PEM header: BEGIN PRIVATE KEY)
  # PKCS#8 EncryptedPrivateKeyInfo** (PEM header: BEGIN ENCRYPTED PRIVATE KEY)
  return "-----BEGIN RSA PRIVATE KEY-----\n" .
         encode_base64($key) .
         "-----END RSA PRIVATE KEY-----\n " if $type eq 'private';
  
  # PKCS#1 RSAPublicKey* (PEM header: BEGIN RSA PUBLIC KEY)
  # X.509 SubjectPublicKeyInfo** (PEM header: BEGIN PUBLIC KEY)
  return "-----BEGIN PUBLIC KEY-----\n" .
         encode_base64($key) .
         "-----END PUBLIC KEY-----\n " if $type eq 'public';
}

sub generate_key {
  my $self = shift;
  $self->_generate_key(@_);
  return $self;
}

sub import_key {
  my ($self, $key) = @_;
  croak "FATAL: undefined key" unless $key;
  my $data;
  if (ref($key) eq 'SCALAR') {
    $data = $$key;
  }
  elsif (-f $key) {
    $data = _slurp_file($key);
  }
  else {
    croak "FATAL: non-existing file '$key'";
  }
  if ($data && $data =~ /-----BEGIN (RSA PRIVATE|RSA PUBLIC|PRIVATE|PUBLIC) KEY-----(.*?)-----END/sg) {
    $data = decode_base64($2);
  }
  croak "FATAL: invalid key format" unless $data;
  $self->_import($data);
  return $self;
}

sub encrypt {
  my ($self, $data, $padding, $hash_name, $lparam) = @_;
  $lparam ||= '';
  $padding ||= 'oaep';
  $hash_name = Crypt::Digest::_trans_digest_name($hash_name||'SHA1');
  
  return $self->_encrypt($data, $padding, $hash_name, $lparam);
}

sub decrypt {
  my ($self, $data, $padding, $hash_name, $lparam) = @_;
  $lparam ||= '';
  $padding ||= 'oaep';
  $hash_name = Crypt::Digest::_trans_digest_name($hash_name||'SHA1');
  
  return $self->_decrypt($data, $padding, $hash_name, $lparam);
}

sub sign {
  my ($self, $data, $padding, $hash_name, $saltlen) = @_;
  $saltlen ||= 12;
  $padding ||= 'pss';
  $hash_name = Crypt::Digest::_trans_digest_name($hash_name||'SHA1');
  
  return $self->_sign($data, $padding, $hash_name, $saltlen);
}

sub verify {
  my ($self, $sig, $data, $padding, $hash_name, $saltlen) = @_;
  $saltlen ||= 12;
  $padding ||= 'pss';
  $hash_name = Crypt::Digest::_trans_digest_name($hash_name||'SHA1');
  
  return $self->_verify($sig, $data, $padding, $hash_name, $saltlen);
}

### FUNCTIONS

sub rsa_encrypt {
  my $key = shift;
  $key = __PACKAGE__->new($key) unless ref $key;
  carp "FATAL: invalid 'key' param" unless ref($key) eq __PACKAGE__;
  return $key->encrypt(@_);
}

sub rsa_decrypt {
  my $key = shift;
  $key = __PACKAGE__->new($key) unless ref $key;
  carp "FATAL: invalid 'key' param" unless ref($key) eq __PACKAGE__;  
  return $key->decrypt(@_);
}

sub rsa_sign {
  my $key = shift;
  $key = __PACKAGE__->new($key) unless ref $key;
  carp "FATAL: invalid 'key' param" unless ref($key) eq __PACKAGE__;  
  return $key->sign(@_);
}

sub rsa_verify {
  my $key = shift;
  $key = __PACKAGE__->new($key) unless ref $key;
  carp "FATAL: invalid 'key' param" unless ref($key) eq __PACKAGE__; 
  return $key->verify(@_);
}

sub _slurp_file {
  my $f = shift;
  local $/ = undef;
  open FILE, "<", $f or croak "FATAL: couldn't open file: $!";
  binmode FILE;
  my $string = <FILE>;
  close FILE;
  return $string;
}

sub CLONE_SKIP { 1 } # prevent cloning

1;

=pod

=head1 NAME

Crypt::PK::RSA - Public key cryptography based on RSA

=head1 SYNOPSIS

 ### OO interface
 
 #Encryption: Alice
 my $pub = Crypt::PK::RSA->new('Bob_pub_rsa1.der'); 
 my $ct = $pub->encrypt("secret message");
 #
 #Encryption: Bob (received ciphertext $ct)
 my $priv = Crypt::PK::RSA->new('Bob_priv_rsa1.der');
 my $pt = $priv->decrypt($ct);
  
 #Signature: Alice
 my $priv = Crypt::PK::RSA->new('Alice_priv_rsa1.der');
 my $sig = $priv->sign($message);
 #
 #Signature: Bob (received $message + $sig)
 my $pub = Crypt::PK::RSA->new('Alice_pub_rsa1.der');
 $pub->verify($sig, $message) or die "ERROR";
 
 #Key generation
 my $pk = Crypt::PK::RSA->new();
 $pk->generate_key(256, 65537);
 my $private_der = $pk->export_key_der('private');
 my $public_der = $pk->export_key_der('public');
 my $private_pem = $pk->export_key_pem('private');
 my $public_pem = $pk->export_key_pem('public');

 ### Functional interface
 
 #Encryption: Alice
 my $ct = rsa_encrypt('Bob_pub_rsa1.der', "secret message");
 #Encryption: Bob (received ciphertext $ct)
 my $pt = rsa_decrypt('Bob_priv_rsa1.der', $ct);
  
 #Signature: Alice
 my $sig = rsa_sign('Alice_priv_rsa1.der', $message);
 #Signature: Bob (received $message + $sig)
 rsa_verify('Alice_pub_rsa1.der', $sig, $message) or die "ERROR";
 
=head1 FUNCTIONS

=head2 rsa_encrypt

See method L<encrypt> below.

 my $ct = rsa_encrypt($pub_key_filename, $message);
 #or
 my $ct = rsa_encrypt(\$buffer_containing_pub_key, $message);
 #or
 my $ct = rsa_encrypt($pub_key, $message, $padding);
 #or
 my $ct = rsa_encrypt($pub_key, $message, 'oaep', $hash_name, $lparam);

=head2 rsa_decrypt

See method L<decrypt> below.

 my $pt = rsa_decrypt($priv_key_filename, $ciphertext);
 #or
 my $pt = rsa_decrypt(\$buffer_containing_priv_key, $ciphertext);
 #or
 my $pt = rsa_decrypt($priv_key, $ciphertext, $padding);
 #or
 my $pt = rsa_decrypt($priv_key, $ciphertext, 'oaep', $hash_name, $lparam);

=head2 rsa_sign

See method L<sign> below.

 my $sig = rsa_sign($priv_key_filename, $message);
 #or
 my $sig = rsa_sign(\$buffer_containing_priv_key, $message);
 #or
 my $sig = rsa_sign($priv_key, $message, $padding);
 #or
 my $sig = rsa_sign($priv_key, $message, $padding, $hash_name);
 #or
 my $sig = rsa_sign($priv_key, $message, 'pss', $hash_name, $saltlen);

=head2 rsa_verify

See method L<verify> below.

 rsa_verify($pub_key_filename, $signature, $message) or die "ERROR";
 #or
 rsa_verify(\$buffer_containing_pub_key, $signature, $message) or die "ERROR";
 #or
 rsa_verify($pub_key, $signature, $message, $padding) or die "ERROR";
 #or
 rsa_verify($pub_key, $signature, $message, $padding, $hash_name) or die "ERROR";
 #or
 rsa_verify($pub_key, $signature, $message, 'pss', $hash_name, $saltlen) or die "ERROR";

=head1 METHODS

=head2 new

  my $pk = Crypt::PK::RSA->new();
  #or
  my $pk = Crypt::PK::RSA->new($priv_or_pub_key_filename);
  #or
  my $pk = Crypt::PK::RSA->new(\$buffer_containing_priv_or_pub_key);

=head2 generate_key

Uses Yarrow-based cryptographically strong random number generator seeded with
random data taken from C</dev/random> (UNIX) or C<CryptGenRandom> (Win32).

 $pk->generate_key($size, $e);
 # $size .. key size: 128-512 bytes (DEFAULT is 256)
 # $e ..... exponent: 3, 17, 257 or 65537 (DEFAULT is 65537)

=head2 import_key

  $pk->import_key($priv_or_pub_key_filename);
  #or
  $pk->import_key(\$buffer_containing_priv_or_pub_key);

=head2 export_key_der

 my $private_der = $pk->export_key_der('private');
 #or
 my $public_der = $pk->export_key_der('public');

=head2 export_key_pem

 my $private_pem = $pk->export_key_pem('private');
 #or
 my $public_pem = $pk->export_key_pem('public');

=head2 encrypt

 my $pk = Crypt::PK::RSA->new($pub_key_filename);
 my $ct = $pk->encrypt($message);
 #or
 my $ct = $pk->encrypt($message, $padding);
 #or
 my $ct = $pk->encrypt($message, 'oaep', $hash_name, $lparam);
 
 # $padding .................... 'oaep' (DEFAULT), 'v1.5' or 'none'
 # $hash_name (only for oaep) .. 'SHA1' (DEFAULT), 'SHA256' (any hash supported by Crypt::Digest)
 # $lparam (only for oaep) ..... DEFAULT is empty string

=head2 decrypt

 my $pk = Crypt::PK::RSA->new($priv_key_filename);
 my $pt = $pk->decrypt($ciphertext);
 #or
 my $pt = $pk->decrypt($ciphertext, $padding);
 #or
 my $pt = $pk->decrypt($ciphertext, 'oaep', $hash_name, $lparam);
 
 #NOTE: $padding, $hash_name, $lparam - see encrypt method

=head2 sign

 my $pk = Crypt::PK::RSA->new($priv_key_filename);
 my $signature = $priv->sign($message);
 #or
 my $signature = $priv->sign($message, $padding);
 #or
 my $signature = $priv->sign($message, $padding, $hash_name);
 #or
 my $signature = $priv->sign($message, 'pss', $hash_name, $saltlen);
 
 # $padding ................. 'pss' (DEFAULT) or 'v1.5'
 # $hash_name ............... 'SHA1' (DEFAULT), 'SHA256' (any hash supported by Crypt::Digest)
 # $saltlen (only for pss) .. DEFAULT is 12

=head2 verify

 my $pk = Crypt::PK::RSA->new($pub_key_filename);
 my $valid = $pub->verify($signature, $message)
 #or
 my $valid = $pub->verify($signature, $message, $padding)
 #or
 my $valid = $pub->verify($signature, $message, $padding, $hash_name);
 #or
 my $valid = $pub->verify($signature, $message, 'pss', $hash_name, $saltlen);
 
 #NOTE: $padding, $hash_name, $saltlen - see sign method

=head2 is_private

 my $rv = $pk->is_private;
 # 1 .. private key loaded
 # 0 .. public key loaded
 # undef .. no key loaded

=head2 size

 my $size = $pk->is_private;
 # returns key size in bytes or undef if no key loaded