package dtRdr::Logger::Appender::WxMessageBox;

our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;
#use Data::Dumper;
use Wx qw(
  :everything
);



sub new {
  my $class = shift;
  my (@options) = @_;
  my $self = {
    name   => "unknown name",
    style => wxICON_ERROR,
    title => 'Error',
    auto_style => 0,
    level2title => {
      ERROR => 'Error',
      WARN  => 'Warning',
      FATAL => 'Fatal Error',
      INFO  => 'Info',
      DEBUG => 'Debug Info'
    },
    level2style => {
      ERROR => wxICON_ERROR,
      WARN  => wxICON_EXCLAMATION,
      FATAL => wxICON_ERROR,
      INFO  => wxICON_INFORMATION,
      DEBUG => wxICON_INFORMATION
    },
    level2instruct => {
      ERROR => 'Press ok to Continue',
      WARN  => 'Press ok to Continue',
      FATAL => 'The application will now terminate',
      INFO  => 'Press ok to Continue',
      DEBUG => 'Press ok to Continue'
    },
    instruct => 'Press OK to Continue',
    parent => undef,
    @options,
  };
  bless $self, $class;
} # end sub new
########################################################################

sub log {
  my $self = shift;
  my (%params) = @_;
  #print Dumper(%params);
  if($self->{auto_style}){
    $self->{title} = $self->{level2title}->{$params{log4p_level}} or die("Couldn't set title");
    $self->{style} = $self->{level2style}->{$params{log4p_level}} or die("Couldn't set style");
    $self->{instruct} = $self->{level2instruct}->{$params{log4p_level}} or die("Couldn't set instruct");
  }
  $params{message} .= "\n$self->{instruct}";
  Wx::MessageBox(
    $params{message},
    $self->{title},
    $self->{style}|wxSTAY_ON_TOP,
    $self->{parent}
  ) or die("Couldn't create Wx::MessageBox");

} # end sub log
########################################################################

1;

__END__

=head1 NAME

dtRdr::Logger::Appender::WxMessageBox - Display error in Wx::MessageBox

=head1 SYNOPSIS

    use dtRdr::Logger::Appender::WxMessageBox;

    my $app = dtRdr::Logger::Appender::WxMessageBox->new(
        style => wxICON_ERROR,
        title => 'Error',
        instruct => 'Press OK to Continue',
        die => 0,
    );

    $file->log(message => "Log me\n");

=head1 DESCRIPTION

This is a simple appender for displaying a Wx Message Dialog.

see: http://www.wxwindows.org/manuals/2.6.3/wx_dialogfunctions.html#wxmessagebox

The constructor C<new()> take optional parameters

=head2 style

The dialog style, may be of type:

wxYES_NO, wxCANCEL, wxOK, wxICON_EXCLAMATION, wxICON_HAND,
wxICON_ERROR, wxICON_QUESTION, wxICON_INFORMATION

=head2 title

The title to appear in the title bar

=head2 instruct

Additional User instructions to place over the Buttons.
If die is set to true you should set this to something like

C<"The application will now terminate">

=head2 parent

The parent widget for the dialog - currently defaults to the top level application window

=head2 auto_style

Boolean -  Sets the Dialog style, title, and instruct message based on the Error Level.

Design and implementation of this module has been greatly inspired by
Dave Rolsky's C<Log::Dispatch> appender framework.

=head1 AUTHOR

Gary Varnell <gvarnell@osoft.com>, Copyright 2006

=head1 COPYRIGHT

Copyright (C) 2006 OSoft, All Rights Reserved.

=head1 NO WARRANTY

Absolutely, positively NO WARRANTY, neither express or implied, is
offered with this software.  You use this software at your own risk.  In
case of loss, no person or entity owes you anything whatseover.  You
have been warned.

=head1 LICENSE

GPL

=cut
