use utf8;
use strict;
use warnings;
use Test::More;

{

    use_ok 'Validation::Class::Document';

}

{

    package T;

    use Validation::Class::Document;

    field 'id' => { filters => ['numeric'], min_length => 1, required => 1 };

    package main;

    my $class = T->new;

    ok "T" eq ref $class, "T instantiated";

    can_ok $class, "id";

    $class->id('ABC');

    ok !$class->validate('id'), "T ID field could not be validated";

}

done_testing;
