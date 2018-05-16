=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Users::Command::Account::User::Add;

### Command module to add a user and a local login object to the database after successful local registration
### @author hr5

use strict;
use warnings;

use EnsEMBL::Users::Messages qw(MESSAGE_EMAIL_INVALID MESSAGE_NAME_MISSING MESSAGE_ALREADY_REGISTERED MESSAGE_ACCOUNT_PENDING MESSAGE_ACCOUNT_DISABLED MESSAGE_UNKNOWN_ERROR MESSAGE_VERIFICATION_SENT);

use parent qw(EnsEMBL::Users::Command::Account);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;

  # validation
  my $fields  = $self->validate_fields({ map {$_ => $hub->param($_) || ''} qw(email name) });
  return $self->redirect_register($fields->{'invalid'} eq 'email' ? MESSAGE_EMAIL_INVALID : MESSAGE_NAME_MISSING, { map {$_ => $hub->param($_) || ''} qw(email name organisation country) }) if $fields->{'invalid'};

  my $email   = $fields->{'email'};
  my $login   = $object->fetch_login_account($email);
  if ($login) {
    my $message;
    if ($login->status eq 'pending') {
      warn '!!! set pending';
      return $self->redirect_register(MESSAGE_ACCOUNT_PENDING, {'email' => $email});
    }
    elsif ($login->status eq 'active') {
      return $self->redirect_login(MESSAGE_ALREADY_REGISTERED, {'email' => $email});
    }
    elsif ($login->status eq 'disabled') {
      return $self->redirect_register(MESSAGE_ACCOUNT_DISABLED, {'email' => $email});
    }
    else {
      return $self->redirect_register(MESSAGE_UNKNOWN_ERROR, {'email' => $email});
    }
  }

  my $user        = $object->fetch_user_by_email($email);

  if ($user) {
    ## This shouldn't get triggered if there's no login, but let's be thorough!
    return $self->redirect_login(MESSAGE_ALREADY_REGISTERED, {'email' => $email});
  }
  else {
    $login = $object->new_login_account({
      'type'              => 'local',
      'status'            => 'pending',
    });

    $login->update_consent($hub->species_defs->GDPR_ACCOUNTS_VERSION);
    $login->subscription([ $hub->param('subscription') ]);
    $login->reset_salt;

=pod
    $user = $object->new_user_account({'email' => $email});

    $user->add_logins([$login]);

    $user->add_memberships([ map { group_id => $_, status => 'active', member_status => 'active' }, @{$hub->species_defs->ENSEMBL_DEFAULT_USER_GROUPS} ]);
    
    $user->save;
=cut
    return $self->redirect_message(MESSAGE_VERIFICATION_SENT, {'email' => $user->email});
  }

}

1;
