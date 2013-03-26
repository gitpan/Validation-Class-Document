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

    field  'state'  => { state => 1 };
    field  'string' => { mixin => ':str' };

    document 'location' => {
        'id'       => 'string',
        'type'     => 'string',
        'name'     => 'string',
        'company'  => 'string',
        'address1' => 'string',
        'address2' => 'string',
        'city'     => 'string',
        'state'    => 'state',
        'zip'      => 'string'
    };

    document 'user' => {
        'id'          => 'string',
        'type'        => 'string',
        'name'        => 'string',
        'company'     => 'string',
        'login'       => 'string',
        'email'       => 'string',
        'locations.@' => 'location'
    };

    package main;

    my $class;

    eval { $class = T->new; };

    ok "T" eq ref $class, "T instantiated";

    my $documents = $class->prototype->settings->get('documents');

    ok "Validation::Class::Mapping" eq ref $documents, "T documents registered as setting";

    ok 2 == $documents->count, "T has 1 registered document";

    my $user = $documents->get('user');

    ok 7 == keys %{$user}, "T user document has 6 mappings";

    can_ok $class, 'validate_document';

    my $data = {
        "id"        => 1234,
        "type"      => "Master",
        "name"      => "Root",
        "company"   => "System, LLC",
        "login"     => "root",
        "email"     => "root\@localhost",
        "locations" => [
            {
                "id"       => 9876,
                "type"     => "Node",
                "name"     => "DevBox",
                "company"  => "System, LLC",
                "address1" => "123 Street Road",
                "address2" => "Suite 2",
                "city"     => "SINCITY",
                "state"    => "NO",
                "zip"      => "00000"
            }
        ]
    };

    ok ! $class->validate_document(user => $data), "T document (user) not valid";
    ok $class->errors_to_string =~ /locations\.0\.state/, "T proper error message set";

    $class->proto->settings->get('documents')->get('location')->{state} = 'string';

    ok $class->validate_document(user => $data), "T document (user) validated";

    #warn $class->errors_to_string if $class->error_count;

}

done_testing;
