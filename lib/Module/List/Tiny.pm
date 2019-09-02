package Module::List::Tiny;

# DATE
# VERSION

#IFUNBUILT
use strict 'subs', 'vars';
use warnings;
#END IFUNBUILT

# do our own exporting to be Tiny
sub import {
    my $pkg = shift;
    my $caller = caller;
    for my $sym (@_) {
        if ($sym eq 'list_modules') { *{"$caller\::$sym"} = \&{$sym} }
        else { die "$sym is not exported!" }
    }
}

sub list_modules($$) {
    my($prefix, $options) = @_;
    my $trivial_syntax = $options->{trivial_syntax};
    my($root_leaf_rx, $root_notleaf_rx);
    my($notroot_leaf_rx, $notroot_notleaf_rx);
    if($trivial_syntax) {
        $root_leaf_rx = $notroot_leaf_rx = qr#:?(?:[^/:]+:)*[^/:]+:?#;
        $root_notleaf_rx = $notroot_notleaf_rx =
            qr#:?(?:[^/:]+:)*[^/:]+#;
    } else {
        $root_leaf_rx = $root_notleaf_rx = qr/[a-zA-Z_][0-9a-zA-Z_]*/;
        $notroot_leaf_rx = $notroot_notleaf_rx = qr/[0-9a-zA-Z_]+/;
    }
    die "bad module name prefix `$prefix'"
        unless $prefix =~ /\A(?:${root_notleaf_rx}::
                               (?:${notroot_notleaf_rx}::)*)?\z/x &&
                                   $prefix !~ /(?:\A|[^:]::)\.\.?::/;
    my $list_modules = $options->{list_modules};
    my $list_prefixes = $options->{list_prefixes};
    my $list_pod = $options->{list_pod};
    my $use_pod_dir = $options->{use_pod_dir};
    return {} unless $list_modules || $list_prefixes || $list_pod;
    my $recurse = $options->{recurse};
    my $return_path = $options->{return_path};
    my @prefixes = ($prefix);
    my %seen_prefixes;
    my %results;
    while(@prefixes) {
        my $prefix = pop(@prefixes);
        my @dir_suffix = split(/::/, $prefix);
        my $module_rx =
            $prefix eq "" ? $root_leaf_rx : $notroot_leaf_rx;
        my $pm_rx = qr/\A($module_rx)\.pmc?\z/;
        my $pod_rx = qr/\A($module_rx)\.pod\z/;
        my $dir_rx =
            $prefix eq "" ? $root_notleaf_rx : $notroot_notleaf_rx;
        $dir_rx = qr/\A$dir_rx\z/;
        foreach my $incdir (@INC) {
            my $dir = join("/", $incdir, @dir_suffix);
            opendir(my $dh, $dir) or next;
            while(defined(my $entry = readdir($dh))) {
                if(($list_modules && $entry =~ $pm_rx) ||
                       ($list_pod &&
                        $entry =~ $pod_rx)) {
                    $results{$prefix.$1} = $return_path ? "$dir/$entry" : undef
                        if !exists($results{$prefix.$1});
                } elsif(($list_prefixes || $recurse) &&
                            ($entry ne '.' && $entry ne '..') &&
                            $entry =~ $dir_rx &&
                            -d join("/", $dir,
                                    $entry)) {
                    my $newpfx = $prefix.$entry."::";
                    next if exists $seen_prefixes{$newpfx};
                    $results{$newpfx} = $return_path ? "$dir/$entry/" : undef
                        if !exists($results{$newpfx}) && $list_prefixes;
                    push @prefixes, $newpfx if $recurse;
                }
            }
            next unless $list_pod && $use_pod_dir;
            $dir = join("/", $dir, "pod");
            opendir($dh, $dir) or next;
            while(defined(my $entry = readdir($dh))) {
                if($entry =~ $pod_rx) {
                    $results{$prefix.$1} = $return_path ? "$dir/$entry" : undef;
                }
            }
        }
    }
    return \%results;
}

1;
# ABSTRACT: A fork of Module::List that starts faster

=head1 SYNOPSIS

 use Module::List::Tiny qw(list_modules);

 $id_modules = list_modules("Data::ID::", { list_modules => 1});
 $prefixes = list_modules("", { list_prefixes => 1, recurse => 1 });


=head1 DESCRIPTION

This module is a fork of L<Module::List>. It's exactly like Module::List, except
with lower startup overhead (see benchmarks in
L<Bencher::Scenarios::ListingModules::Startup>). To accomplish this, it:

=over

=item * does its own exporting instead of using L<Exporter>

=item * avoids using L<Carp> and uses the good old C<die>

=item * avoids using L<IO::Dir> and uses plain C<opendir>

The problem is that IO::Dir brings in a bunch of other modules.

=item * avoids using L<File::Spec> and hard-code path separator as C</>

C</> happens to work everywhere with current platforms anyway.

=back


=head1 SEE ALSO

L<Module::List>

L<PERLANCAR::Module::List> - my other, personal fork, with additional features

=cut
