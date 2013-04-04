# ABSTRACT: Data Validation for Hierarchical Data

package Validation::Class::Document;

use utf8;
use strict;
use warnings;

use Validation::Class ();
use Validation::Class::Exporter;
use Validation::Class::Mapping;

use Hash::Flatten 'flatten', 'unflatten';
use Carp  'croak';
use Clone 'clone';

Validation::Class::Exporter->apply_spec(
    routines => ['doc', 'document', 'validate_document', 'document_validates'],
);

my $i = 0; # IAMTHATIAM



sub doc { goto &document } sub document {

    my $package = shift if @_ == 3;

    my ($name, $data) = @_;

    $data ||= {};

    return unless ($name && $data);

    return Validation::Class::configure_class_proto( $package => sub {

        my ($proto) = @_;

        my  $settings = $proto->configuration->settings;

            $settings->{documents} ||= {};

            $settings->{documents}->{$name} = $data;

        return $proto;

    })

};


sub document_validates { goto &validate_document } sub validate_document {

    my ($self, $ref, $data, $options) = @_;

    my $name;

    my $proto     = $self->prototype;

    my $documents = clone $proto->settings->get('documents');

    my $_fmap     = {}; # ad-hoc fields

    if ("HASH" eq ref $ref) {

        $ref  = clone $ref;

        $name = "DOC_" . time() . ++$i;

        # build document on-the-fly from a hashref
        foreach my $rules (values %{$ref}) {

            next unless "HASH" eq ref $rules;

            my  $id = uc "$rules";
                $id =~ s/\W/_/g;
                $id =~ s/_$//;

            $proto->fields->add($id => $rules);
            $rules = $id;
            $_fmap->{$id} = 1;

        }

        $documents->{$name} = $ref;

    }

    else {

        $name = $ref;

    }

    my $fields    = { map {$_ => 1} ($proto->fields->keys) };

    croak "Please supply a registered document name to validate against"
        unless $name
    ;

    croak "The ($name) document is not registered and cannot be validated against"
        unless $name && exists $documents->{$name}
    ;

    my $document = $documents->{$name};

    croak "The ($name) document does not contain any mappings and cannot ".
          "be validated against" unless keys %{$documents}
    ;

    $options ||= {};

    for my  $key (keys %{$document}) {

        $document->{$key} = $documents->{$document->{$key}} if
            $document->{$key} && exists $documents->{$document->{$key}} &&
            ! $proto->fields->has($document->{$key})
        ;

    }

    $document = flatten $document;

    for my  $key (keys %{$document}) {

        my  $value = delete $document->{$key};

        my  $token;
        my  $regex;

            $token  = '\.\@';
            $regex  = ':\d+';
            $key    =~ s/$token/$regex/g;

            $token  = '\*';
            $regex  = '[^\.]+';
            $key    =~ s/$token/$regex/g;

        $document->{$key} = $value;

    }

    my $_dmap = {};
    my $_pmap = {};
    my $_xmap = {};

    my $_data = flatten $data;

    for my $key (keys %{$_data}) {

        my  $point = $key;
            $point =~ s/\W/_/g;
        my  $label = $key;
            $label =~ s/\:/./g;

        my  $match = 0;

        for my $regex (keys %{$document}) {

            if ($_data->{$key}) {

                my  $field = $document->{$regex};

                if ($key =~ /^$regex$/) {

                    my $config = {label => $label};

                    $config->{mixin} = $proto->fields->get($field)->mixin
                        if $proto->fields->get($field)->can('mixin')
                    ;

                    $proto->clone_field($field, $point => $config);

                    $proto->apply_mixin($point => $config->{mixin})
                        if $config->{mixin}
                    ;

                    $_dmap->{$key}   = 1;
                    $_pmap->{$point} = $key;

                    $match = 1;

                }

            }

        }

        $_xmap->{$point} = $key;

        # register node as a parameter

        $proto->params->add($point => $_data->{$key})
            unless $options->{prune} && ! $match
        ;

        # queue and force requirement

        $proto->queue("+$point")
            unless $options->{prune} && ! $match
        ;

        # prune unnecessary nodes

        if ($options->{prune} && ! $match) {

            delete $_data->{$key};

        }

    }

    $proto->validate($self);

    $proto->clear_queue;

    my @errors = $proto->get_errors;

    for (sort @errors) {

        my ($message) = $_ =~ /field (\w+) does not exist/;

        next unless $message;

        $message = $_xmap->{$message};

        next unless $message;

        $message  =~ s/\W/./g;

        # re-format unknown parameter errors
        $_ = "The parameter $message was not expected and could not be validated";

    }

    $_dmap = unflatten $_dmap;

    while (my($point, $key) = each(%{$_pmap})) {

        $_data->{$key} = $proto->params->get($point); # prepare data

        $proto->fields->delete($point) unless $fields->{$point}; # reap clones

    }

    $proto->fields->delete($_) for keys %{$_fmap}; # reap ad-hoc fields

    $proto->reset_fields;

    $proto->set_errors(@errors) if @errors; # report errors

    $_[2] = unflatten $_data if defined $_[2]; # restore data

    return $proto->is_valid;

}

1;

__END__

=pod

=head1 NAME

Validation::Class::Document - Data Validation for Hierarchical Data

=head1 VERSION

version 0.000015

=head1 SYNOPSIS

    package MyApp::Person;

    use Validation::Class::Document;

    my $person = MyApp::Person->new;

    # rules

    my $schema = {
        'id'                        => {mixin => [':num'], max_length => 4},
        'name'                      => {mixin => [':str'], min_length => 2},
        'title'                     => {mixin => [':str'], min_length => 5},
        'company.name'              => {mixin => [':str'], min_length => 2},
        'company.tags.@'            => {mixin => [':str'], min_length => 2},
        'company.super*.name'       => {mixin => [':str'], min_length => 2},
        'company.super*.rating.@.*' => {mixin => [':str'], },
    };

    # data

    my $data = {
        "id"      => "1234-ABC",
        "name"    => "Anita Campbell-Green",
        "title"   => "Designer",
        "company" => {
            "name"       => "House of de Vil",
            "supervisor" => {
                "name"   => "Cruella de Vil",
                "rating" => [
                    {   "support"  => -9,
                        "guidance" => -9
                    }
                ]
            },
            "tags" => [
                "evil",
                "cruelty",
                "dogs"
            ]
        },
    };

    unless ($person->validate_document($schema => $data)) {
        warn $person->errors_to_string if $person->error_count;
    }

=head1 DESCRIPTION

Validation::Class::Document inherits all functionality from L<Validation::Class>
and implements additional abilities documented as follows.

This module allows you to validate hierarchical structures using the
L<Validation::Class> framework. This is an experimental yet highly promising
approach toward the consistent processing of nested structures. The current
interface is not expected to change. This module was inspired by
L<MooseX::Validation::Doctypes>. Gone are the days of data submitted to an
application in key/value form and especially in regards to the increasing demand
for communication between applications, serializing and transmitting structured
data over a network connection. Note! All matching data points will be validated
forcefully (i.e. matching data points are required to have a value defined).

=head1 OVERVIEW

Validation::Class::Document exports the document (or dom) keyword which allows
you to pre-define/configure your path matching rules for your data structure.
The "path matching rules", which is actually a custom object notation, referred
to as the document notation, can be thought of as a kind-of simplified regular
expression which is executed against the flattened data structure. The following
are a few general use-cases:

    # given this JSON data structure
    {
        "id": "1234-A",
        "name": {
            "first_name" : "Bob",
            "last_name"  : "Smith",
         },
        "title": "CIO",
        "friends" : [],
    }

    # select id to validate against the string rules
    document 'foobar'  =>
        { 'id' => 'string' };

    # select name -> first_name/last_name to validate against the string rules
    document 'foobar'  =>
        {'name.first_name' => 'string', 'name.last_name' => 'string'};

    # or
    document 'foobar'  =>
        {'name.*_name' => 'string'};

    # select each element in friends to validate against the string rules
    document 'foobar'  =>
        { 'friends.@'  => 'string' };

    # or select an element of a hashref in each element in friends to validate
    document 'foobar'  =>
        { 'friends.@.name' => 'string' };

The document declaration's keys should follow the aforementioned document
notation schema and it's values should be strings which correspond to the names
of fields (or other document declarations) that will be used to preform the
data validation. It is possible to combine document declarations to validate
hierarchical data that contains data structures matching one or more document
patterns. The following is an example of what that might look like.

    package MyApp::Person;

    use Validation::Class::Document;

    # data validation rule
    field  'name' => {
        mixin      => [':str'],
        pattern    => qr/^[A-Za-z ]+$/,
        max_length => 20,
    };

    # data validation map / document notation schema
    document 'friend' => {
        'name' => 'name'
    };

    # data validation map / document notation schema
    document 'person' => {
        'name' => 'name',
        'friends.@' => 'friend'
    };

    package main;

    my $data = {
        "name"   => "Anita Campbell-Green",
        "friends" => [
            { "name" => "Horace" },
            { "name" => "Skinner" },
            { "name" => "Alonzo" },
            { "name" => "Frederick" },
        ],
    };

    my $person = MyApp::Person->new;

    unless ($person->validate_document(person => $data)) {
        warn $person->errors_to_string if $person->error_count;
    }

Alternatively, the following is a more verbose data validation class using
traditional styling and configuration.

    package MyApp::Person;

    use Validation::Class::Document;

    field  'id' => {
        mixin      => [':str'],
        filters    => ['numeric'],
        max_length => 2,
    };

    field  'name' => {
        mixin      => [':str'],
        pattern    => qr/^[A-Za-z ]+$/,
        max_length => 20,
    };

    field  'rating' => {
        mixin      => [':str'],
        pattern    => qr/^\-?\d+$/,
    };

    field  'tag' => {
        mixin      => [':str'],
        pattern    => qr/^(?!evil)\w+/,
        max_length => 20,
    };

    document 'person' => {
        'id'                             => 'id',
        'name'                           => 'name',
        'company.name'                   => 'name',
        'company.supervisor.name'        => 'name',
        'company.supervisor.rating.@.*'  => 'rating',
        'company.tags.@'                 => 'name'
    };

    package main;

    my $data = {
        "id"      => "1234-ABC",
        "name"    => "Anita Campbell-Green",
        "title"   => "Designer",
        "company" => {
            "name"       => "House of de Vil",
            "supervisor" => {
                "name"   => "Cruella de Vil",
                "rating" => [
                    {   "support"  => -9,
                        "guidance" => -9
                    }
                ]
            },
            "tags" => [
                "evil",
                "cruelty",
                "dogs"
            ]
        },
    };

    my $person = MyApp::Person->new;

    unless ($person->validate_document(person => $data)) {
        warn $person->errors_to_string if $person->error_count;
    }

=head1 METHODS

=head2 validate_document

The validate_document method (or document_validates) is used to validate the
specified hierarchical data against the specified document declaration. This is
extremely valuable for validating serialized messages passed between machines.
This method requires two arguments, the name of the document declaration to be
used, and the data to be validated which should be submitted in the form of a
hashref. The following is an example of this technique:

    my $boolean = $self->validate_document(foobar => $data);

Additionally, you may submit options in the form of a hashref to further control
the validation process. The following is an example of this technique:

    # the prune option removes non-matching parameters (nodes)
    my $boolean = $self->validate_document(foobar => $data, { prune => 1 });

Additionally, to support the validation of ad-hoc specifications, you may pass
this method two hashrefs, the first being the document notation schema, and the
second being the hierarchical data you wish to validate.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
