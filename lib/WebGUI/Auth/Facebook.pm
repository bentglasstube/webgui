package WebGUI::Auth::Facebook;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2010 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use base 'WebGUI::Auth';
use Facebook::Graph;

=head1 NAME

WebGUI::Auth::Facebook -- Facebook auth for WebGUI

=head1 DESCRIPTION

Allow Facebook users to authenticate to WebGUI

=head1 METHODS

These methods are available from this class:

=cut

#----------------------------------------------------------------------------

=head2 new ( ... )

Create a new object

=cut

sub new {
    my $self    = shift->SUPER::new(@_);
    return bless $self, __PACKAGE__; # Auth requires rebless
}

#----------------------------------------------------------------------------

=head2 createFacebookUser ( fbuser )

    my $user    = $self->createFacebookUser(  $fb->fetch('me') );

Create a new Facebook::Graph user.

=cut

sub createFacebookUser {
    my ( $self, $fbuser ) = @_;
    my $user    = WebGUI::User->create( $self->session );
    $user->username( $fbuser->{name} );
    $user->profileField('email', $fbuser->{email});
    $user->profileField('firstName', $fbuser->{first_name});
    $user->profileField('lastName', $fbuser->{last_name});
    $self->saveParams( $user->userId, $self->authMethod, { 
        "facebookUserId" => $fbuser->{id},
    } );
    return $user;
}

#----------------------------------------------------------------------------

=head2 editUserSettingsForm ( )

Return the form to edit the settings of this Auth module

=cut

sub editUserSettingsForm {
    my $self = shift;
    my $session = $self->session;
    my ( $setting ) = $session->quick(qw( setting ));
    my $i18n = WebGUI::International->new( $session, 'Auth_Facebook' );

    my $f = WebGUI::HTMLForm->new( $session );

    $f->yesNo(
        name        => 'facebookAuthEnabled',
        value       => $setting->get( 'facebookAuthEnabled' ),
        label       => $i18n->get('enabled'),
        hoverHelp   => $i18n->get('enabled help'),
    );

    $f->text(
        name        => 'facebookAuthAppId',
        value       => $setting->get( 'facebookAuthAppId' ),
        label       => $i18n->get('app id'),
        hoverHelp   => $i18n->get('app id help'),
        subtext     => $i18n->get('get app id'),
    );

    $f->text(
        name        => 'facebookAuthSecret',
        value       => $setting->get( 'facebookAuthSecret' ),
        label       => $i18n->get('secret'),
        hoverHelp   => $i18n->get('secret help'),
    );

    $f->template(
        name        => 'facebookAuthTemplateIdChooseUsername',
        value       => $setting->get( 'facebookAuthTemplateIdChooseUsername' ),
        label       => $i18n->get('choose username template'),
        hoverHelp   => $i18n->get('choose username template help'),
        namespace   => 'Auth/Facebook/ChooseUsername',
    );

    return $f->printRowsOnly;
}

#----------------------------------------------------------------------------

=head2 editUserSettingsFormSave ( )

Process the form for this Auth module's settings

=cut

sub editUserSettingsFormSave {
    my $self    = shift;
    my $session = $self->session;
    my ( $form, $setting ) = $session->quick(qw( form setting ));

    my @fields  = qw( 
        facebookAuthEnabled facebookAuthAppId facebookAuthSecret 
        facebookAuthTemplateIdChooseUsername 
    );
    for my $field ( @fields ) {
        $setting->set( $field, $form->get( $field ) );
    }

    return;
}

#----------------------------------------------------------------------------

=head2 getTemplateChooseUsername ( )

Get the template to choose a username

=cut

sub getTemplateChooseUsername {
    my ( $self ) = @_;
    my $templateId  = $self->session->setting->get('facebookAuthTemplateIdChooseUsername');
    return WebGUI::Asset->newById( $self->session, $templateId );
}

#----------------------------------------------------------------------------

=head2 getFacebook ( )

Get the Facebook::Graph object with the appropriate keys

=cut

sub getFacebook {
    my ( $self ) = @_;
    my ( $url, $scratch, $setting ) = $self->session->quick( qw( url scratch setting ) );
    if ( !$self->{_fb} ) {
        my $fb = Facebook::Graph->new(
            app_id          => $setting->get( 'facebookAuthAppId' ),
            secret          => $setting->get( 'facebookAuthSecret' ),
            postback        => $url->getSiteURL . $url->page('op=auth&authType=Facebook&method=callback'),
        );
        if ($scratch->get('facebookAuthAccessToken')) {
            $fb->access_token($scratch->get('facebookAuthAccessToken'));
        }
        $self->{_fb} = $fb;
    }
    return $self->{_fb};
}

#----------------------------------------------------------------------------

=head2 www_login ( )

Begin the login procedure

=cut

sub www_login {
    my ( $self ) = @_;
    my $session = $self->session;
    my ( $url, $scratch, $setting ) = $session->quick( qw( url scratch setting ) );

    my $auth_url = $self->getFacebook
        ->authorize
        ->extend_permissions(qw(email))
        ->uri_as_string;

    $session->http->setRedirect($auth_url);
    return "redirect";
}

#----------------------------------------------------------------------------

=head2 www_callback ( )

Callback from the Facebook authentication. Try to log the user in, creating a 
new user account if necessary. 

If the username is taken, allow the user to choose a new one.

=cut

sub www_callback {
    my ( $self ) = @_;
    my $session = $self->session;
    my ( $form, $scratch, $db, $setting ) = $session->quick(qw( form scratch db setting ));

    # handle facebook stuff
    my $fb = $self->getFacebook;
    $fb->request_access_token($form->get('code'));
    $scratch->set('facebookAuthAccessToken', $fb->access_token);
    my $fbuser = $fb->fetch('me');


    ### Log the user in
    # Find their FB user ID
    my $userId  = $db->quickScalar( 
        "SELECT userId FROM authentication WHERE authMethod = ? AND fieldName = ? AND fieldData = ?",
        [ "Facebook", "facebookUserId", $fbuser->{id} ],
    );

    # Returning user
    if ( $userId ) {
        my $user    = WebGUI::User->new( $session, $userId );
        $self->user( $user );
        return $self->login;
    }
    # Otherwise see if their screen name exists and create a user
    elsif ( !WebGUI::User->newByUsername( $session, $fbuser->{name}) ) {
        my $user = $self->createFacebookUser( $fbuser );
        $self->user( $user );
        return $self->login;
    }

    # Otherwise ask them for a new username to use
    my $i18n = WebGUI::International->new( $session, 'Auth_Facebook' );
    my $tmpl    = $self->getTemplateChooseUsername;
    my $var     = {
        message     => sprintf( $i18n->get("username taken"), $fbuser->{name} ),
    };

    return $tmpl->process( $var );
}

#----------------------------------------------------------------------------

=head2 www_setUsername ( )

Set the username for a fb user. Only used as part of the initial fb
registration.

=cut

sub www_setUsername {
    my ( $self ) = @_;
    my $session = $self->session;
    my ( $form, $scratch, $db ) = $session->quick(qw( form scratch db ));
    my $i18n = WebGUI::International->new( $session, 'Auth_Facebook' );

    # Don't allow just anybody to set a username
    my $fb = $self->getFacebook;
    return if $fb->access_token eq '';

    my $fbuser = $fb->fetch('me');
    $fbuser->{name} = $form->get('newUsername');

    if ( !WebGUI::User->newByUsername( $session, $fbuser->{name} ) ) {
        my $user = $self->createFacebookUser( $fbuser );
        $self->user( $user );
        return $self->login;
    }

    # Username is again taken! Noooooo!
    my $tmpl    = $self->getTemplateChooseUsername;
    my $var     = {
        message     => sprintf( $i18n->get("username taken"), $fbuser->{name} ),
    };

    return $tmpl->process( $var );
}

1;