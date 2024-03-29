use utf8;
use strict;
use warnings;
use Test::More;

{

    use_ok 'Validation::Class::Document';

}

{

    package T1;

    use Validation::Class::Document;

    field 'string' => {
        mixin => ':str'
    };

    document 'user' => {
        'id'          => 'string',
        'name'        => 'string',
        'email'       => 'string',
        'comp*'       => 'string'
    };

    package main;

    my $class;

    eval {

        $class = T1->new(
            ignore_failure => 1,
            ignore_unknown => 1,
            report_failure => 1,
            report_unknown => 1
        );

    };

    ok "T1" eq ref $class, "T1 instantiated";

    my $documents = $class->prototype->settings->get('documents');

    ok "HASH" eq ref $documents, "T1 documents hash registered as setting";

    ok 1 == keys %{$documents}, "T1 has 1 registered document";

    my $user = $documents->{user};

    ok 4 == keys %{$user}, "T1 user document has 3 mappings";

    can_ok $class, 'validate_document';

    my $data = {
        "id"        => 1234,
        "type"      => "Master",
        "name"      => "Root",
        "company"   => "System, LLC",
        "login"     => "root",
        "email"     => "root\@localhost",
        "office_locations" => [
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

    ok ! $class->validate_document(user => $data), "T1 document (user) not valid";
    ok 11 == $class->error_count, "T1 document failed with 11 errors";
    ok $class->errors_to_string =~ /office_locations\.0\.id was not expected/, "T1 document errors look okay";

    # warn $class->errors_to_string("\n");

}

{

    package T2;

    use Validation::Class::Document;

    field 'string' => {
        mixin => ':str'
    };

    document 'user' => {
        'id'          => 'string',
        'name'        => 'string',
        'email'       => 'string',
        'comp*'       => 'string'
    };

    package main;

    my $class;

    eval {

        $class = T2->new(
            ignore_failure => 1,
            ignore_unknown => 1,
            report_failure => 0,
            report_unknown => 0
        );

    };

    ok "T2" eq ref $class, "T2 instantiated";

    my $documents = $class->prototype->settings->get('documents');

    ok "HASH" eq ref $documents, "T2 documents hash registered as setting";

    ok 1 == keys %{$documents}, "T2 has 1 registered document";

    my $user = $documents->{user};

    ok 4 == keys %{$user}, "T2 user document has 3 mappings";

    can_ok $class, 'validate_document';

    my $data = {
        "id"        => 1234,
        "type"      => "Master",
        "name"      => "Root",
        "company"   => "System, LLC",
        "login"     => "root",
        "email"     => "root\@localhost",
        "office_locations" => [
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

    ok $class->validate_document(user => $data), "T2 document (user) valid";
    ok 0 == $class->error_count, "T2 document has no errors";

    # warn $class->errors_to_string("\n");

}

done_testing;
