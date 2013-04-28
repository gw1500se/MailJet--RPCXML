package MailJet::RPCXML;
# This is a perl class for the MailJet API
#
# Written by Dennis Putnam
# Date: Apr 2013
#
use strict;
use Switch;
use Carp;
use URI::Escape;
use WWW::Curl::Easy;
use XML::Simple;
use Data::Dumper;

our $VERSION='1.0';

sub new {
	my $proto=shift;
	my $class=ref($proto)||$proto;
	my $self={};
	$self->{version}="0.1";
	$self->{output}="xml";
	$self->{debug}=0;
	$self->{apiKey}=shift;
	$self->{secretKey}=shift;
	$self->{apiUrl}="https://api.mailjet.com/".$self->{version};
	$self->{webUrl}="https://www.mailjet.com";
	bless($self,$class);
	return($self);
}

sub requestUrlBuilder {
	my $self=shift;
	my $method=shift;
	my $request=shift;
	my $params=shift;
	if ($self->{debug}) {
		carp("requestUrlBuilder - Parameters hash:\n".Dumper(%{$params})."\n");
	}
	my @query=("output=".$self->{output});
	foreach my $parm (sort keys %{$params}) {
		if ($request eq "GET" || $parm eq "apikey" || $parm eq "output") {
			push(@query,"$parm=".uri_escape($$params{$parm}));
		}
		if ($parm eq "output" ) {
			$self->{output}=$$params{$parm};
		}
	}
	my $url=$self->{apiUrl}."/$method/?".join('&',@query);
	return($url);
}

sub buildQuery {
	my $self=shift;
	my $params=shift;
	my $string;
	foreach my $parm (sort keys %{$params}) {
		$string.="$parm=".uri_escape($$params{$parm})."&";
	}
	$string=substr($string,0,length($string)-1);
	if ($self->{debug}) {
		print("buildQuery - Post string: $string\n");
	}
	return($string);
}

sub sendRequest {
	my $self=shift;
	my $method=shift;
	my $request=shift;
	my %params=();
	for (my $i=0; $i<=$#_; $i+=2) {
		$params{$_[$i]}=$_[$i+1];
	}
	my $url=$self->requestUrlBuilder($method,$request,\%params);
	if ($self->{debug}) {
		print("sendRequest - Using URL: $url\n");
	}
	my $xml=XML::Simple->new();
	my $curl=WWW::Curl::Easy->new();
	my $response;
	my $page;
	$curl->setopt(CURLOPT_URL,$url);
	$curl->setopt(CURLOPT_SSL_VERIFYPEER,0);
	$curl->setopt(CURLOPT_SSL_VERIFYHOST,2);
	$curl->setopt(CURLOPT_USERPWD,$self->{apiKey}.":".$self->{secretKey});
	$curl->setopt(CURLOPT_WRITEDATA,\$response);
	if ($request eq "POST") {
		$curl->setopt(CURLOPT_POST,$#_);
		$curl->setopt(CURLOPT_POSTFIELDS,$self->buildQuery(\%params));
	}
	my $ret=$curl->perform();
	if ($ret==0) {
		my $code=$curl->getinfo(CURLINFO_HTTP_CODE);
		switch ($code) {
			case 200 {
				if ($self->{debug}) {
					print("sendRequest - Raw response:\n$response\n");
				}
				$page=$xml->XMLin($response);
				$page->{status}=$code;
			}
			else {
				$page=$xml->XMLin("<?xml version=\"1.0\" encoding=\"utf-8\"?><xml><status>$code</status></xml>");
			}
		}
		if ($self->{debug}) {
			print("sendRequest - XML:\n".Dumper($page)."\n");
		}

	}
	else {
		carp("sendRequest error ($ret): ".$curl->strerror($ret)." ".$curl->errbuf."\n");
	}
	return($page);
}

sub getUserId {
	my $self=shift;
	my $email=shift;
	my $xml=$self->sendRequest("userSenderlist","GET",());
	if ($self->{debug}) {
		print("GetUserId - userSenderlist returned:\n".Dumper($xml)."\n");
	}
	if ($xml->{status}!=200) {
		return(-1);
	}
	foreach my $id (sort keys %{$xml->{senders}{item}}) {
		if ($xml->{senders}{item}{$id}{email} eq $email) {
			return($id);
		}	
	}
	return(0);
}

1;

=head1 NAME

MailJet::RPCXML - API Class for MailJet

=head1 VERSION

Version 1.0

=head1 AUTHOR

Dennis Putnam

=head1 SYNOPSIS

Mailjet::RPCXML -  Perl module for simplifying interaction with the MailJet API

=head1 DESCRIPTION

This module is a perl class for the MailJet Cloud Emailing API (http://www.mailjet.com).
It sends API requests using curl to api.mailjet.com and returns the result as an XML object.
Although not every one was tested it should fully support all documented API methods.

=over 4

=over 4

=item use strict;

=item use MailJet::RPCXML;

=item use Data::Dumper;

=item my $mailjet=MailJet::RPCXML->new('apiKey','secretKey');

=item my $response=$mailjet->sendRequest("userSenderstatus","POST",("email",'someone@somwhere.com'));

=item print(Dumper($response)."\n");

=back

=back

=head1 IMPORTANT LINKS

=over 4

=item * L<https://www.mailjet.com/docs/api>

=back

Note that while there is no specific documentation for Perl, the reference methods and parameters apply.

=head1 CONSTRUCTOR

=head2 new('apiKey','secretKey')

Creates and returns a new MailJet object. The 'apiKey' and 'secretKey' are the login parameters provided
by MailJet when you open an account.

=head1 METHODS

=head2 sendRequest(...)

Returns the result of an API method as an XML object. Three arguments are required although the last can be
an empty array.

The first argument is a string representing the API method (e.g. 'userInfos').

The second argument is the request type and must be either 'POST' or 'GET' depending on
the API method being invoked.

The third argument is an array containing pairs of parameters as needed by the API method being used.

This method always returns at least a <status> XML node representing HTML status codes. The API returns an 'OK'
status but this class changes it to 200. This assures consistancy of an integer data type for this node. All
other nodes are presented as returned by the API.

=head2 getUserID(<email address>)

Returns the MailJet User ID number of the given email address. If there was an error it returns -1 and if the
email address was not found, returns 0.

=head1 INTERNAL METHODS

The following methods are avaliable but would not ordinarily be used outside the class.

=head2 requestUrlBuilder(...)

Returns a string representing the URL formatted for performing the API request. Three arguments are required
but the last can be an empty hash.

The first argument is a string representing the API method (e.g. 'userInfos').

The second argument is the request type and must be either 'POST' or 'GET' depending on
the API method being invoked.

The third argument is a hash consisting of API parameter names (e.g. 'output') as keys and their respective values.

=head2 buildQuery(...)

Returns a string formatted for a POST request. There is one required argument which is a hash consisting of API
parameter names (e.g. 'output') as keys and their respective values.

=head1 OBJECTS

The following objects are available for modification as appropriate.

=head2 version

This is the current version of the API to be accessed. Its value is '0.1' by default. Only change this if MailJet
offers a different version.

=head2 output

This specifies the API should return reponses in XML format. Changing this will likely break the module so do it at
your own peril.

=head2 debug

Setting this value to 1 will generate debug output written to STDOUT.

=head2 apiKey

This is the apiKey assigned by MailJet when you open an account. It normally is set in the 'new' method.

=head2 secretKey

This is the secretKey assigned by MailJet when you open an account. It normally is set in the 'new' method.

=head2 apiURL

This is the url used for all curl requests. It consists of the MailJet API host and the API version.

=head1 DEPENDENCIES

This module requires the following CPAN modules:

=over 4

=item Switch

=item URI::Escape

=item WWW::Curl::Easy - This requrires curlib

=item XML::Simple

=item Data::Dumper - Used when debugging is turned on

=back

=head1 COPYRIGHT

Copyright (c) 2013 Dennis Putnam. All rights reserved. This is free sofware redistributable under the same terms as Perl itself.
=cut
