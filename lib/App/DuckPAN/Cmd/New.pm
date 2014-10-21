package App::DuckPAN::Cmd::New;
# ABSTRACT: Take a name as input and generates a new, named Goodie or Spice instant answer skeleton

# For Goodies:
# 	- <name>.pm file is created in lib/DDG/Goodie
#
# For Spice:
# 	- <name>.pm file is created in lib/DDG/Spice
# 	- directory /share/spice/<name> is created
# 	- <name.js> is created in /share/spice/<name>
# 	- <name.handlebars> is created in /share/spice/<name>

use Moo;
with qw( App::DuckPAN::Cmd );
use Text::Xslate qw(mark_raw);
use IO::All;

sub run {
	my ( $self, @args ) = @_;

	# Check which IA repo we're in...
	my $type = $self->app->get_ia_type();

	# Instant Answer name as parameter
	my $entered_name = (@args) ? join(' ', @args) : $self->app->get_reply('Please enter a name for your Instant Answer');
	$entered_name =~ s/\//::/g; #change "/" to "::" for easier handling
	my $name = $self->app->phrase_to_camel($entered_name);
	my ($package_name, $separated_name, $path, $lc_path) = ($name, $name, "", "");
	$separated_name =~ s/::/ /g;

	if ($entered_name =~ m/::/) {
		my @path_parts = split(/::/, $entered_name);
		if (scalar @path_parts > 1) {
			$name = pop @path_parts;
			$path = join("/", @path_parts);
			$lc_path = join("/", map { $self->app->camel_to_underscore($_) } @path_parts);
		} else {
			$self->app->print_text("[ERROR] Malformed input. Please provide a properaly formatted package name for your Instant Answer.");
		}
	}

	my $lc_name = $self->app->camel_to_underscore($name);
	my $filepath    = ($path eq "") 	? $name    : "$path/$name";
	my $lc_filepath = ($lc_path eq "") 	? $lc_name : "$lc_path/$lc_name";
	if (scalar $lc_path) {
		$lc_path =~ s/\//_/g; #safe to modify, we already used this in $lc_filepath
		$lc_name = $lc_path."_".$lc_name;
	}

	# %templates forms the spine data structure which is used
	# as a guide to discovering content which is moved around
	my %templates = (
		Goodie => {
			dirs => [
				"./lib/DDG/Goodie/$path",
				"./t/$path",
			],
			files => {
				"./template/lib/DDG/Goodie/Example.pm" => "./lib/DDG/Goodie/$filepath.pm",
				"./template/t/Example.t" => "./t/$filepath.t",
			},
		},

		Spice => {
			share_dir => "./share/spice/$lc_filepath",
			dirs => [
				"./lib/DDG/Spice/$path",
				"./t/$path",
				"./share/spice/$lc_path",
				"./share/spice/$lc_path",
			],
			files => {
				"./template/lib/DDG/Spice/Example.pm" => "./lib/DDG/Spice/$filepath.pm",
				"./template/t/Example.t" => "./t/$filepath.t",
				"./template/share/spice/example/example.handlebars" => "./share/spice/$lc_filepath/$lc_name.handlebars",
				"./template/share/spice/example/example.js" => "./share/spice/$lc_filepath/$lc_name.js"
			}
		},
		Fathead => {
			# [TODO] Implement Fathead templates
		},
		Longtail => {
			# [TODO] Implement Fathead templates
		}
	);

	unless (defined $templates{$type}) {
		$self->app->print_text("[ERROR] No templates exist for this IA Type: $type");
		exit -1;
	}

	while (my ($source, $dest) = each(%{$templates{$type}{'files'}})) {
		my $io = io($dest);
		if ($io->exists) {
			my $filename = $io->filename;
			my $filepath= $io->filepath;
			$self->app->print_text("[ERROR] File already exists: \"$filename\" in $filepath");
			exit -1;
		}
		unless (-e $source) {
			$self->app->print_text("[ERROR] Template does not exist: $source");
			exit -1;
		}

		my $tx = Text::Xslate->new();
		my %vars = (
			ia_name => $name,
			ia_package_name => $package_name,
			ia_name_separated => $separated_name,
			lia_name => $lc_name,
			ia_path => $filepath
		);

		my $content = $tx->render($source, \%vars);
		$io->file->assert->append($content); #create file path and append to file
		$self->app->print_text("Created file: $dest");
	}
	$self->app->print_text("Successfully created $type: $package_name");
}

1;
