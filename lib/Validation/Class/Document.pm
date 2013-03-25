# ABSTRACT: Data Validation for Hierarchical Data

package Validation::Class::Document;

use utf8;
use strict;
use warnings;

use Validation::Class ();
use Validation::Class::Exporter;
use Validation::Class::Mapping;

use Hash::Flatten 'flatten', 'unflatten';
use Carp 'croak';

Validation::Class::Exporter->apply_spec(
    routines => ['doc', 'document', 'validate_document', 'document_validates'],
);

sub doc { goto &document } sub document {

    my $package = shift if @_ == 3;

    my ($name, $data) = @_;

    $data ||= {};

    return unless ($name && $data);

    return Validation::Class::configure_class_proto( $package => sub {

        my ($proto) = @_;

        my $settings = $proto->configuration->settings;

        my $documents  = $settings->{documents} ||= Validation::Class::Mapping->new;

        $documents->add($name => $data);

        return $proto;

    })

};

sub document_validates { goto &validate_document } sub validate_document {

    my ($self, $name, $data) = @_;

    my $proto  = $self->prototype;
    my $fields = { map {$_ => 1} ($proto->fields->keys) };

    croak "Please supply a registered document name to validate against"
        unless $name
    ;

    my $documents = $proto->settings->get('documents');

    croak "The ($name) document is not registered and cannot be validated against"
        unless $name && $documents->has($name)
    ;

    my $document = $documents->get($name);

    croak "The ($name) document does not contain any mappings and cannot ".
          "be validated against" unless keys %{$documents}
    ;

    for my  $key (keys %{$document}) {

        my  $value = delete $document->{$key};
            $key   = quotemeta($key);

        my  $token;
        my  $regex;

            $token  = '\\\.\\\@';
            $regex  = '\:\d+';
            $key    =~ s/$token/$regex/g;

            $token  = '\\\\\\*';
            $regex  = '[^\.]+';
            $key    =~ s/$token/$regex/g;

        $document->{$key} = $value;

    }

    my $_dmap = {};
    my $_pmap = {};

    my $_data = flatten $data;

    for my $key (keys %{$_data}) {

        for my $regex (keys %{$document}) {

            if (exists $_data->{$key}) {

                my  $field = $document->{$regex};
                my  $point = $key;
                    $point =~ s/\W/_/g;
                my  $label = $key;
                    $label =~ s/\:/./g;

                if ($key =~ /^$regex$/) {

                    $proto->clone_field($field => $point, {label => $label});

                    $_dmap->{$key}   = 1;
                    $_pmap->{$point} = $key;

                }

                $proto->params->add($point => $_data->{$key});
                $proto->queue("+$point"); # queue and force requirement

            }

        }

    }

    my $result = $proto->validate($self);
    my @errors = $proto->get_errors;

    $_dmap = unflatten $_dmap;

    while (my($point, $key) = each(%{$_pmap})) {
        $_data->{$key} = $proto->params->get($point); # prepare data
        $proto->fields->delete($point) unless $fields->{$point}; # reap clones
    }

    $proto->reset_fields;

    $proto->set_errors(@errors) if @errors; # report errors

    $_[2] = unflatten $_data if defined $_[2]; # restore data

    return $result;

}


1;

__END__

=pod

=head1 NAME

Validation::Class::Document - Data Validation for Hierarchical Data

=head1 VERSION

version 0.000008

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module allows you to validate hierarchical structures using the
L<Validation::Class> framework. This is an experimental yet highly promising
approach toward the consistent processing of nested structures. The current
interface is not expected to change. This module was inspired by
L<MooseX::Validation::Doctypes>. Gone are the days of data submitted to an
application in key/value form and especially in regards to the increasing demand
for communication between applications, serializing and transmitting structured
data over a network connection.

=head1 AUTHOR

Al Newkirk <anewkirk@ana.io>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Al Newkirk.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
