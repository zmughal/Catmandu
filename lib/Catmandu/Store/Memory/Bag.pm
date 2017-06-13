package Catmandu::Store::Memory::Bag;

our $VERSION = '1.0507';

use Catmandu::Sane;
use Moo;
use Catmandu::Util;
use Catmandu::FileStore::MimeType;
use namespace::clean;

with 'Catmandu::Bag', 'Catmandu::FileStore::Bag', 'Catmandu::Droppable';

has _mimeType => (is => 'lazy');

sub _build__mimeType {
    Catmandu::FileStore::MimeType->new;
}

sub generator {
    my ($self) = @_;

    my $name  = $self->name;
    my $files = $self->store->_files->{$name} // {};

    sub {
        state $ids = [ keys %$files ];

        my $id = pop @$ids;

        return undef unless $id;

        return $self->get($id);
    };
}

sub exists {
    my ($self, $id) = @_;

    my $name  = $self->name;
    my $files = $self->store->_files->{$name} // {};

    exists $files->{$id};
}

sub get {
    my ($self, $id) = @_;

    my $name  = $self->name;
    my $files = $self->store->_files->{$name} // {};

    $files->{$id};
}

sub add {
    my ($self, $data) = @_;

    my $id    = $data->{_id};
    my $io    = $data->{_stream};

    delete $data->{_stream};

    my $name  = $self->name;

    my $str = Catmandu::Util::read_io($io);

    $self->store->_files->{$name}->{$id} = {
        _id      => $id ,
        size     => length $str ,
        md5      => '' ,
        content_type => $self->_mimeType->content_type($id) ,
        created  => time ,
        modified => time ,
        _stream  => sub {
            my $io = $_[0];

            Catmandu::Error->throw("no io defined or not writable") unless defined($io);

            $io->write($str);
        } ,
        %$data
    };

    1;
}

sub delete {
    my ($self, $id) = @_;

    my $name  = $self->name;
    my $files = $self->store->_files->{$name} // {};

    delete $files->{$id};
}

sub delete_all {
    my ($self) = @_;

    $self->each(sub {
        my $key = shift->{_id};
        $self->delete($key);
    });

    1;
}

sub drop {
    $_[0]->delete_all;
}

sub commit {
    return 1;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Store::Memory::Bag - Index of all "files" in a Catmandu::Store::Memory "folder"

=head1 SYNOPSIS

    use Catmandu;

    my $store = Catmandu->store('Memory');

    my $index = $store->index;

    # List all containers
    $index->each(sub {
        my $container = shift;

        print "%s\n" , $container->{_id};
    });

    # Add a new folder
    $index->add({_id => '1234'});

    # Delete a folder
    $index->delete(1234);

    # Get a folder
    my $folder = $index->get(1234);

    # Get the files in an folder
    my $files = $index->files(1234);

    $files->each(sub {
        my $file = shift;

        my $name         = $file->_id;
        my $size         = $file->size;
        my $content_type = $file->content_type;
        my $created      = $file->created;
        my $modified     = $file->modified;

        $file->stream(IO::File->new(">/tmp/$name"), file);
    });

    # Add a file
    $files->upload(IO::File->new("<data.dat"),"data.dat");

    # Retrieve a file
    my $file = $files->get("data.dat");

    # Stream a file to an IO::Handle
    $files->stream(IO::File->new(">data.dat"),$file);

    # Delete a file
    $files->delete("data.dat");

    # Delete a folders
    $index->delete("1234");

=head1 DESCRIPTION

A L<Catmandu::Store::Memory::Bag> contains all "files" available in a
L<Catmandu::Store::Memory> FileStore "folder". All methods of L<Catmandu::Bag>,
L<Catmandu::FileStore::Index> and L<Catmandu::Droppable> are
implemented.

Every L<Catmandu::Bag> is also an L<Catmandu::Iterable>.

=head1 FOLDERS

All files in a L<Catmandu::Store::Memory> are organized in "folders". To add
a "folder" a new record needs to be added to the L<Catmandu::Store::Memory::Index> :

    $index->add({_id => '1234'});

The C<_id> field is the only metadata available in Memory stores. To add more
metadata fields to a Memory store a L<Catmandu::Plugin::SideCar> is required.

=head1 FILES

Files can be accessed via the "folder" identifier:

    my $files = $index->files('1234');

Use the C<upload> method to add new files to a "folder". Use the C<download> method
to retrieve files from a "folder".

    $files->upload(IO::File->new("</tmp/data.txt"),'data.txt');

    my $file = $files->get('data.txt');

    $files->download(IO::File->new(">/tmp/data.txt"),$file);

=head1 METHODS

=head2 each(\&callback)

Execute C<callback> on every "file" in the Memory store "folder". See L<Catmandu::Iterable> for more
iterator functions

=head2 exists($name)

Returns true when a "file" with identifier $name exists.

=head2 add($hash)

Adds a new "file" to the Memory store "folder". It is very much advised to use the
C<upload> method below to add new files

=head2 get($id)

Returns a hash containing the metadata of the file. The hash contains:

    * _id : the file name
    * size : file file size
    * content_type : the content_type
    * created : the creation date of the file
    * modified : the modification date of the file
    * _stream: a callback function to write the contents of a file to an L<IO::Handle>

If is very much advised to use the C<stream> method below to retrieve files from
the store.

=head2 delete($name)

Delete the "file" with name $name, if exists.

=head2 delete_all()

Delete all files in this folder.

=head2 upload(IO::Handle,$name)

Upload the IO::Handle reference to the Memory store "folder" and use $name as identifier.

=head2 stream(IO::Handle,$file)

Write the contents of the $file returned by C<get> to the IO::Handle.

=head1 SEE ALSO

L<Catmandu::Store::Memory::Bag> ,
L<Catmandu::Store::Memory> ,
L<Catmandu::FileStore::Index> ,
L<Catmandu::Plugin::SideCar> ,
L<Catmandu::Bag> ,
L<Catmandu::Droppable> ,
L<Catmandu::Iterable>

=cut