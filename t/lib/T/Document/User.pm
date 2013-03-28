package T::Document::User;

use Validation::Class::Document;

field  'string' => { mixin => ':str' };

document 'user' => {
    'id'          => 'string',
    'type'        => 'string',
    'name'        => 'string',
    'company'     => 'string',
    'login'       => 'string',
    'email'       => 'string',
    'locations.@' => 'location'
};

1;
