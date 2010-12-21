package Catmandu::App::Router;
# ABSTRACT: HTTP router
# VERSION
use namespace::autoclean;
use Moose;
use Catmandu::App::Router::Route;
use List::Util qw(max);
use overload q("") => sub { $_[0]->stringify };

has routes => (
    traits => ['Array'],
    is => 'ro',
    isa => 'ArrayRef[Catmandu::App::Router::Route]',
    default => sub { [] },
    handles => {
        route_list => 'elements',
        add_routes => 'push',
        has_routes => 'count',
    },
);

sub steal_routes {
    my ($self, $path, $router, $defaults) = @_;

    confess "Malformed path: path must start with a slash" if $path !~ /^\//;

    $defaults ||= {};

    $self->add_routes(map {
        Catmandu::App::Router::Route->new(
            app => $_->app,
            sub => $_->sub,
            methods => $_->methods,
            defaults => { %{$_->defaults}, %$defaults },
            path => $path . $_->path,
        );
    } $router->route_list);
    $self;
}

sub route {
    my $self = shift;
    $self->add_routes(Catmandu::App::Router::Route->new(@_));
    $self;
}

sub match {
    my ($self, $env) = @_;

    $env = { PATH_INFO => $env } unless ref $env;

    for my $route ($self->route_list) {
        my $match = $route->match($env);
        return $match, $route if $match;
    }
    return;
}

sub stringify {
    my $self = shift;

    my $max_a = max(map { length $_->app } $self->route_list);
    my $max_m = max(map { length join(',', $_->method_list) } $self->route_list);
    my $max_s = max(map { $_->named ? length $_->sub : 7 } $self->route_list);

    join '', map {
        sprintf "%-${max_a}s %-${max_m}s %-${max_s}s %s\n",
            $_->app,
            join(',', $_->method_list),
            $_->named ? $_->sub : 'CODEREF',
            $_->path;
    } $self->route_list;
}

__PACKAGE__->meta->make_immutable;

1;

