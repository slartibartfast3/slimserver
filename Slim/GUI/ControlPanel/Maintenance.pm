package Slim::GUI::ControlPanel::Maintenance;

# SqueezeCenter Copyright 2001-2009 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use base 'Wx::Panel';

use Wx qw(:everything);
use Wx::Event qw(EVT_BUTTON);

use Slim::Utils::Light;
use Slim::Utils::ServiceManager;

my %checkboxes;

sub new {
	my ($self, $nb, $parent, $args) = @_;

	$self = $self->SUPER::new($nb);
	$self->{args} = $args;

	my $mainSizer = Wx::BoxSizer->new(wxVERTICAL);
	
	$mainSizer->Add(Wx::StaticText->new($self, -1, string('CLEANUP_DESC')), 0, wxALL, 5);

	my $cbSizer = Wx::BoxSizer->new(wxVERTICAL);

	foreach (@{ $args->{options} }) {
		
		# support only wants these three options
		next unless $_->{name} =~ /^(?:prefs|cache|all)$/;
		
		$checkboxes{$_->{name}} = Wx::CheckBox->new( $self, -1, $_->{title}, $_->{position});
		$cbSizer->Add( $checkboxes{$_->{name}}, 0, wxTOP | wxGROW, $_->{margin} || 5 );
	}

	$mainSizer->Add($cbSizer, 1, wxALL, 5);

	my $hint = Wx::StaticText->new($self, -1, string('CLEANUP_PLEASE_STOP_SC'));
	$parent->addStatusListener($hint);
	$mainSizer->Add($hint, 0, wxALL, 5);

	my $btnsizer = Wx::StdDialogButtonSizer->new();

	my $btnCleanup = Wx::Button->new( $self, -1, string('CLEANUP_DO') );
	EVT_BUTTON( $self, $btnCleanup, \&doCleanup );
	
	$btnsizer->SetAffirmativeButton($btnCleanup);
	
	$btnsizer->Realize();

	$mainSizer->Add($btnsizer, 0, wxALIGN_BOTTOM | wxALL | wxALIGN_RIGHT, 10);
	
	$self->SetSizer($mainSizer);

	return $self;
}

sub doCleanup {
	my( $self, $event ) = @_;

	# return if no option was selected
	return unless grep { $checkboxes{$_}->GetValue() } keys %checkboxes;
	
	my $svcMgr = Slim::Utils::ServiceManager->new();
	
	if ($svcMgr->checkServiceState() == SC_STATE_RUNNING) {
		
		my $msg = Wx::MessageDialog->new($self, string('CLEANUP_WANT_TO_STOP_SC'), string('CLEANUP_DO'), wxYES_NO | wxNO_DEFAULT | wxICON_QUESTION);
		
		if ($msg->ShowModal() == wxID_YES) {
			# stop SC before continuing
			Slim::GUI::ControlPanel->serverRequest('stopserver');
			
			# wait while SC is being shut down
			my $wait = 59;
			while ($svcMgr->checkServiceState != SC_STATE_STOPPED && $wait > 0) {
				sleep 5;
				$wait -= 5;
			}
		}
		else {
			# don't do anything
			return;
		}
	}
		
	my $params = {};
	my $selected = 0;
		
	foreach (@{ $self->{args}->{options} }) {
		
		next unless $checkboxes{$_->{name}};
		
		$params->{$_->{name}} = $checkboxes{$_->{name}}->GetValue();
		$selected ||= $checkboxes{$_->{name}}->GetValue();
	}
	
	if ($selected) {
		Wx::BusyCursor->new();
			
		my $folders = $self->{args}->{folderCB}($params);

		$self->{args}->{cleanCB}($folders) if $folders;
	}
}

1;