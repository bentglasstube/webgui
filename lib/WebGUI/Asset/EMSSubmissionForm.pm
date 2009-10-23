package WebGUI::Asset::EMSSubmissionForm;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use Tie::IxHash;
use base 'WebGUI::Asset';
use JSON;
use WebGUI::Utility;

# TODO:
# To get an installer for your wobject, add the Installable AssetAspect
# See WebGUI::AssetAspect::Installable and sbin/installClass.pl for more
# details

=head1 NAME

Package WebGUI::Asset::EMSSubmissionForm

=head1 DESCRIPTION

This Asset describes and builds a form which provides an interface for submitting a custom
subset of the EMSTicket asset.  Users create submissions which can be editted by admins
and then become EMSTicket's.

=head1 SYNOPSIS

use WebGUI::Asset::EMSSubmissionForm;

=head1 TODO

add a lastSubmissionDate -- after that the submission form will be closed
    the link will still exist but the form will just say '<title> submissions closed as of <date>'


=head1 METHODS

These methods are available from this class:

=cut

use lib '/root/pb/lib'; use dav;

#-------------------------------------------------------------------

=head2 addSubmission

Creates an EMSSubmission object based on the params
( called by www_saveSubmission )

=cut

sub addSubmission {
    my $self = shift;
    my $form = $self->session->form;
    my $newParams = {};
    my $fieldList = $self->getFormDescription->{_fieldList};
    for  my $field ( @$fieldList ) {
        $newParams->{$field} = $form->get($field);
    }
    $newParams->{className} = 'WebGUI::Asset::EMSSubmission';
    $newParams->{status} = 'pending';
    $newParams->{submissionId} = $self->get('nextSubmissionId');
    $self->update({nextSubmissionId => $newParams->{submissionId}+1 });
    $self->addChild($newParams);
}

#-------------------------------------------------------------------

=head2 addRevision

This me>thod exists for demonstration purposes only.  The superclass
handles revisions to NewAsset Assets.

=cut

#sub addRevision {
#    my $self    = shift;
#    my $newSelf = $self->SUPER::addRevision(@_);
#    return $newSelf;
#}

#-------------------------------------------------------------------

=head2 canSubmit

returns true if current user can submit using this form

=cut

sub canSubmit {
    my $self = shift;

    return $self->session->user->isInGroup($self->get('canSubmitGroupId'));
}

#-------------------------------------------------------------------

=head2 definition ( session, definition )

defines asset properties for New Asset instances.  You absolutely need 
this method in your new Assets. 

=head3 session

=head3 definition

A hash reference passed in from a subclass definition.

=cut

sub definition {
    my $class      = shift;
    my $session    = shift;
    my $definition = shift;
    my $i18n       = WebGUI::International->new( $session, "Asset_EMSSubmissionForm" );
    tie my %properties, 'Tie::IxHash', (
        nextSubmissionId => { 
            tab          => "properties",
            fieldType    => "integer",
            defaultValue => 0,
            label        => $i18n->get("next submission id label"),
            hoverHelp    => $i18n->get("next submission id label help")
        },
        canSubmitGroupId => { 
            tab          => "security",
            fieldType    => "group",
            defaultValue => 2,
            label        => $i18n->get("can submit group label"),
            hoverHelp    => $i18n->get("can submit group label help")
        },
        daysBeforeCleanup => { 
            tab          => "properties",
            fieldType    => "integer",
            defaultValue => 7,
            label        => $i18n->get("days before cleanup label"),
            hoverHelp    => $i18n->get("days before cleanup label help")
        },
        deleteCreatedItems => { 
            tab          => "properties",
            fieldType    => "yesNo",
            defaultValue => undef,
            label        => $i18n->get("delete created items label"),
            hoverHelp    => $i18n->get("delete created items label help")
        },
        submissionDeadline => { 
            tab          => "properties",
            fieldType    => "Date",
            defaultValue => '677496912', # far in the future...
            label        => $i18n->get("submission deadline label"),
            hoverHelp    => $i18n->get("submission deadline label help")
        },
        pastDeadlineMessage => { 
            tab          => "properties",
            fieldType    => "HTMLArea",
            defaultValue => $i18n->get('past deadline message'),
            label        => $i18n->get("past deadline label"),
            hoverHelp    => $i18n->get("past deadline label help")
        },
        formDescription => { 
            tab          => "properties",
            fieldType    => "textarea",
            defaultValue => '{ }',
            label        => $i18n->get("form dscription label"),
            hoverHelp    => $i18n->get("form dscription label help")
        },
    );
    push @{$definition}, {
        assetName         => $i18n->get('assetName'),
        icon              => 'EMSSubmissionForm.gif',
        autoGenerateForms => 1,
        tableName         => 'EMSSubmissionForm',
        className         => 'WebGUI::Asset::EMSSubmissionForm',
        properties        => \%properties,
    };
    return $class->SUPER::definition( $session, $definition );
} ## end sub definition

#-------------------------------------------------------------------

=head2 duplicate

This method exists for demonstration purposes only.  The superclass
handles duplicating NewAsset Assets.  This method will be called 
whenever a copy action is executed

=cut

#sub duplicate {
#    my $self     = shift;
#    my $newAsset = $self->SUPER::duplicate(@_);
#    return $newAsset;
#}

#-------------------------------------------------------------------

=head2  www_editSubmissionForm  ( [ parent, ] [ params ] )

create an html form for user to enter params for a new submissionForm asset

=head3 parent

the parent ems object -- needs to be passed only if this is a class level call

=head3 params

optional set of possibly incorrect submission form params

=cut

sub www_editSubmissionForm {
	my $this             = shift;
        my $self;
        my $parent;
        if( $this eq __PACKAGE__ ) {  # called as constructor or menu
	    $parent             = shift;
        } else {
            $self = $this;
            $parent = $self->getParent;
        }
	my $params           = shift || { };
	my $session = $parent->session;
	my $i18n = WebGUI::International->new($parent->session,'Asset_EventManagementSystem');
        my $assetId = $self ? $self->getId : $params->{assetId} || $session->form->get('assetId');

        if( ! defined( $assetId ) ) {
	   my $res = $parent->getLineage(['children'],{ returnObjects => 1,
		 includeOnlyClasses => ['WebGUI::Asset::EMSSubmissionForm'],
	     } );
	    if( scalar(@$res) == 1 ) {
	        $self = $res->[0];
		$assetId = $self->getId;
	    } else {
	        my $makeAnchorList =sub{ my $u=shift; my $n=shift; my $d=shift;
		            return qq{<li><a href='$u' title='$d'>$n</a></li>} } ;
	        my $listOfLinks = join '', ( map {
		      $makeAnchorList->(
		                $parent->getUrl('func=editSubmissionForm;assetId=' . $_->getId ),
				$_->get('title'),
				WebGUI::HTML::filter($_->get('description'),'all')
		             )
		           } ( @$res ) );
		return $parent->processStyle( '<h1>' . $i18n->get('select form to edit') .
		                            '</h1><ul>' . $listOfLinks . '</ul>' );
	    }
        } elsif( $assetId ne 'new' ) {
	    $self &&= WebGUI::Asset->newByDynamicClass($session,$assetId);
	    if (!defined $self) { 
		$session->errorHandler->error(__PACKAGE__ . " - failed to instanciate asset with assetId $assetId");
	    }
        }
        my $url = ( $self || $parent )->getUrl('func=editSubmissionFormSave');
	my $newform = WebGUI::HTMLForm->new( $session, action => $url );
	$newform->hidden(name => 'assetId', value => $assetId);
	my @fieldNames = qw/title description startDate duration seatsAvailable location/;
	my $fields;
	my @defs = reverse @{WebGUI::Asset::EMSSubmission->definition($session)};
dav::dump 'editSubmissionForm::definition:', [@defs];
	for my $def ( @defs ) {
	    foreach my $fieldName ( @fieldNames ) {
                my $properties = $def->{properties};
	        if( defined $properties->{$fieldName} ) {
		      $fields->{$fieldName} = { %{$properties->{$fieldName}} }; # a simple first level copy
		      # field definitions don't contain their own name, we will need it later on
		      $fields->{$fieldName}{fieldId} = $fieldName;
		  };
	    }
	}
	for my $metaField ( @{$parent->getEventMetaFields} ) {
	    push @fieldNames, $metaField->{fieldId};
	    $fields->{$metaField->{fieldId}} = { %$metaField }; # a simple first level copy
	    # meta fields call it data type, we copy it to simplify later on
	    $fields->{$metaField->{fieldId}}{fieldType} = $metaField->{dataType};
	}
	$newform->hidden( name => 'fieldNames', value => join( ' ', @fieldNames ) );
	@defs = reverse @{WebGUI::Asset::EMSSubmissionForm->definition($session)};
dav::dump 'editSubmissionForm::dump submission form def', \@defs ;
        for my $def ( @defs ) {
	    my $properties = $def->{properties};
	    for my $fieldName ( qw/title menuTitle url description canSubmitGroupId daysBeforeCleanup
                               deleteCreatedItems submissionDeadline pastDeadlineMessage/ ) {
	        if( defined $properties->{$fieldName} ) {
                    my %fieldParams = %{$properties->{$fieldName}};
		    $fieldParams{name} = $fieldName;
		    $fieldParams{value} = $params->{$fieldName} || $self ? $self->get($fieldName) : undef ;
dav::dump 'editSubmissionForm::properties for ', $fieldName, \%fieldParams ;
		    $newform->dynamicField(%fieldParams);
		}
	    }
        }
dav::dump 'editSubmissionForm::dump before generate:',$fields;

	my $formDescription = $params->{formDescription} || $self ? $self->getFormDescription : { };
        for my $fieldId ( @fieldNames ) {
	    my $field = $fields->{$fieldId};
	    $newform->yesNo(
	             label => $field->{label},
		     name => $field->{fieldId} . '_yesNo',
		     defaultValue => 0,
		     value => $formDescription->{$field->{fieldId}},
	    );
	}
	$newform->submit; 
	return $parent->processStyle(
               $parent->processTemplate({
		      errors => $params->{errors} || [],
                      backUrl => $parent->getUrl,
		      pageForm => $newform->print,
                  },$parent->get('eventSubmissionFormTemplateId')));
}

#-------------------------------------------------------------------

=head2  www_editSubmissionFormSave  

test and save new params

=cut

sub www_editSubmissionFormSave {
        my $self = shift;
        return $self->session->privilege->insufficient() unless $self->canEdit;
        my $formParams = $self->processForm();
        if( $formParams->{_isValid} ) {
            delete $formParams->{_isValid};
            $self->update($formParams);
            return $self->getParent->www_viewSubmissionQueue;
        } else {
            return $self->www_editSubmissionForm($formParams);
        }
}

#-------------------------------------------------------------------

=head2 getFormDescription

returns a hash ref decoded from the JSON in the form description field

=cut

sub getFormDescription {
    my $self = shift;
    return JSON->new->decode($self->get('formDescription'));
}

#-------------------------------------------------------------------

=head2 indexContent ( )

Making private. See WebGUI::Asset::indexContent() for additonal details. 

=cut

#sub indexContent {
#    my $self    = shift;
#    my $indexer = $self->SUPER::indexContent;
#    $indexer->setIsPublic(0);
#}

#-------------------------------------------------------------------

=head2 prepareView ( )

See WebGUI::Asset::prepareView() for details.

=cut

sub prepareView {
    my $self = shift;
    $self->SUPER::prepareView();
    my $template = WebGUI::Asset::Template->new( $self->session, $self->get("templateId") );
    $template->prepare($self->getMetaDataAsTemplateVariables);
    $self->{_viewTemplate} = $template;
}

#-------------------------------------------------------------------

=head2 processPropertiesFromFormPost ( )

Used to process properties from the form posted.  Do custom things with
noFormPost fields here, or do whatever you want.  This method is called
when /yourAssetUrl?func=editSave is requested/posted.

=cut

sub processPropertiesFromFormPost {
    my $self = shift;
    $self->SUPER::processPropertiesFromFormPost;
}

#-------------------------------------------------------------------

=head2 purge ( )

This method is called when data is purged by the system.
removes collateral data associated with a NewAsset when the system
purges it's data.  This method is unnecessary, but if you have 
auxiliary, ancillary, or "collateral" data or files related to your 
asset instances, you will need to purge them here.

=cut

#sub purge {
#    my $self = shift;
#    return $self->SUPER::purge;
#}

#-------------------------------------------------------------------

=head2 purgeRevision ( )

This method is called when data is purged by the system.

=cut

#sub purgeRevision {
#    my $self = shift;
#    return $self->SUPER::purgeRevision;
#}

#-------------------------------------------------------------------

=head2 view ( )

method called by the container www_view method. 

=cut

sub view {
    my $self = shift;
    my $var  = $self->get;    # $var is a hash reference.
    $var->{controls} = $self->getToolbar;
    return $self->processTemplate( $var, undef, $self->{_viewTemplate} );
}


#----------------------------------------------------------------

=head2 www_addSubmission ( )

calls www_editSubmission with assetId == new

=cut

sub www_addSubmission {
    my $self = shift;
    $self->www_editSubmission( { assetId => 'new' } );
}

#-------------------------------------------------------------------

=head2 www_edit ( )

Web facing method which is the default edit page.  Unless the method needs
special handling or formatting, it does not need to be included in
the module.

=cut

sub www_edit {
    my $self    = shift;
    my $session = $self->session;
    return $session->privilege->insufficient() unless $self->canEdit;
    return $session->privilege->locked()       unless $self->canEditIfLocked;
    my $i18n = WebGUI::International->new( $session, 'Asset_EMSSubmissionForm' );
    return $self->getAdminConsole->render( $self->getEditForm->print, $i18n->get('edit asset') );
}

#-------------------------------------------------------------------

=head2  www_editSubmission  { params }

calls WebGUI::Asset::EMSSubmission->editSubmission

=cut

sub www_editSubmission {
    my $self             = shift;
    return $self->session->privilege->insufficient() unless $self->canEdit;
    return WebGUI::Asset::EMSSubmission->www_editSubmission($self,shift);
}

#-------------------------------------------------------------------

=head2  www_editSubmissionSave

validate and create a new submission

=cut

sub www_editSubmissionSave {
        my $self = shift;
        return $self->session->privilege->insufficient() unless $self->canEdit;
        my $formParams = WebGUI::Asset::EMSSubmission->processForm($self);
        if( $formParams->{_isValid} ) {
            delete $formParams->{_isValid};
            $self->addSubmission($formParams);
            return $self->www_viewSubmissionQueue;
        } else {
            return $self->www_editSubmission($formParams);
        }
}

#----------------------------------------------------------------

=head2 processForm ( $parent )

pull data componenets out of $session->form

=head3 parent

reference to the EMS asset that is parent to the new submission form asset

=cut

use lib '/root/pb/lib'; use dav;

sub processForm {
    my $this = shift;
    my $form;
    if( $this eq __PACKAGE__ ) {
	my $parent = shift;
	$form = $parent->session->form;
    } elsif( ref $this eq __PACKAGE__ ) {
	$form = $this->session->form;
    } else {
        return {_isValid => 0, errors => [ { text => 'invalid function call' } ] };
    }
    my $params = {_isValid=>1};
    for my $fieldName ( qw/assetId title menuTitle url description canSubmitGroupId daysBeforeCleanup
		       deleteCreatedItems submissionDeadline pastDeadlineMessage/ ) {
	$params->{$fieldName} = $form->get($fieldName);
    }
    my @fieldNames = split( ' ', $form->get('fieldNames') );
    $params->{formDescription} = { map { $_ => $form->get($_ . '_yesNo') } ( @fieldNames ) };
    $params->{formDescription}{_fieldList} = [ map { $params->{formDescription}{$_} ? $_ : () } ( @fieldNames ) ];
    if( scalar( @{$params->{formDescription}{_fieldList}} ) == 0 ) {
	$params->{_isValid} = 0;
	push @{$params->{errors}}, {text => 'you should turn on at least one entry field' }; # TODO internationalize this
    }
dav::dump 'processForm::params:', $params;
    return $params;
}

=head TODO work on this code
# this is a bunch of code that will likely be useful for this function...
{
	    for my $fieldName ( qw/title menuTitle url description canSubmitGroupId daysBeforeCleanup
                               deleteCreatedItems submissionDeadline pastDeadlineMessage/ ) {
	        if( defined $properties->{$fieldName} ) {
                    my %param = %{$properties->{$fieldName}};
		    $param{value} = $form->get($fieldName) || $self ? $self->get($fieldName) : $param{defaultValue} || '';
		    $param{name} = $fieldName;
dav::dump 'editSubmissionForm::properties for ', $fieldName, \%param ;
		    $maintab->dynamicField(%param);
		}
	    }
        }
dav::dump 'editSubmissionForm::dump before generate:',$fields;
}
=cut

}

#-------------------------------------------------------------------

=head2 update ( )

We overload the update method from WebGUI::Asset in order to handle file system privileges.

=cut

sub update {
    my $self = shift;
    my $properties = shift;
    if( ref $properties->{formDescription} eq 'HASH' ) {
        $properties->{formDescription} = JSON->new->encode($properties->{formDescription}||{});
    }
    $self->SUPER::update({%$properties, isHidden => 1});
}

1;

#vim:ft=perl
