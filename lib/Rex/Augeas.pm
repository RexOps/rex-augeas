#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Augeas;

use strict;
use warnings;

require Exporter;

our $VERSION = "0.1.0";

use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;

use Config::Augeas;
use IO::String;

@EXPORT = qw(augeas);

sub augeas {
   my ($action, $file, @options) = @_;
   my $ret;

   Rex::Logger::debug("Creating Config::Augeas Object");
   my $aug = Config::Augeas->new;

   my $is_ssh = Rex::is_ssh();

   if($action eq "modify") {
      my $config_option = { @options };

      for my $key (keys %{$config_option}) {
         my $aug_key = "/files$file$key";
         Rex::Logger::debug("modifying $aug_key -> " . $config_option->{$key});

         my $_r;
         if($is_ssh) {
            run 'echo "set ' . $aug_key . ' ' . $config_option->{$key} . '" | augtool -s';
            if($? == 0) {
               $_r = 1;
            }
            else {
               $_r = 0;
            }
         }
         else {
            $_r = $aug->set($aug_key, $config_option->{$key});
         }
         Rex::Logger::debug("Augeas set status: $_r");
      }

      $ret = $aug->save;
   }
   elsif($action eq "remove") {
      for my $key (@options) {
         my $aug_key = "/files$file$key";
         Rex::Logger::debug("deleting $aug_key");

         my $_r;
         if($is_ssh) {
            run "echo 'rm $aug_key' | augtool -s";
            if($? == 0) {
               $_r = 1;
            }
            else {
               $_r = 0;
            }
         }
         else {
            $_r = $aug->remove($aug_key);
         }
         Rex::Logger::debug("Augeas delete status: $_r");
      }

      $ret = $aug->save;
   }
   elsif($action eq "insert") {
      my $opts = { @options };
      my $label = $opts->{"label"};
      delete $opts->{"label"};

      if($is_ssh) {
         my $position = (exists $opts->{"before"}?"before":"after");
         unless(exists $opts->{$position}) {
            Rex::Logger::info("Error inserting key. You have to specify before or after.");
            return 0;
         }
         
         delete $opts->{$position};

         my $aug_commands = "ins $label $position " . $opts->{$position} . "\n";

         for(my $i=0; $i < @options; $i+=2) {
            my $key = $options[$i];
            my $val = $options[$i+1];
            next if($key eq "after" or $key eq "before" or $key eq "label");

            my $_key = "/files$file/$label/$key";
            Rex::Logger::debug("Setting $_key => $val");

            $aug_commands .= "set $_key $val\n";
         }

         $aug_commands .= "save\n";

         my $tmp_file = "/tmp/" . get_random(12, 'a'..'z', 0..9) . '.tmp';
         my $fh = file_write $tmp_file;
         $fh->write($aug_commands);
         $fh->close;

         run "cat $tmp_file | augtool";

         $ret = 0;
         if($? == 0) {
            $ret = 1;
         }

         unlink "$tmp_file";
      }
      else {
         if(exists $opts->{"before"}) {
            $aug->insert($label, before => "/files$file" . $opts->{"before"});
            delete $opts->{"before"};
         }
         elsif(exists $opts->{"after"}) {
            my $t = $aug->insert($label, after => "/files$file" . $opts->{"after"});
            delete $opts->{"after"};
         }
         else {
            Rex::Logger::info("Error inserting key. You have to specify before or after.");
            return 0;
         }

         for(my $i=0; $i < @options; $i+=2) {
            my $key = $options[$i];
            my $val = $options[$i+1];

            next if($key eq "after" or $key eq "before" or $key eq "label");

            my $_key = "/files$file/$label/$key";
            Rex::Logger::debug("Setting $_key => $val");

            $aug->set($_key, $val);
         }

         $ret = $aug->save();
      }
   }
   elsif($action eq "dump") {
      my $aug_key = "/files$file";

      if($is_ssh) {
         my @list = run "augtool print $aug_key";
         print join("\n", @list) . "\n";
      }
      else {
         $aug->print($aug_key);
      }
      $ret = 0;
   }
   elsif($action eq "exists") {
      my $aug_key = "/files$file/" . $options[0];
      my $val = $options[1] || "";

      if($is_ssh) {
         my @paths = grep { s/\s=[^=]+$// } run "echo 'match $aug_key' | augtool";

         if($val) {
            for my $k (@paths) {
               my @ret = grep { s/^[^=]+=\s// } run "echo 'get $k' | augtool";
               
               if($ret[0] eq $val) {
                  return $k;
               }
            }
         }
         else {
            return @paths;
         }

         $ret = undef;
      }
      else {
         my @paths = $aug->match($aug_key);

         if($val) {
            for my $k (@paths) {
               if($aug->get($k) eq $val) {
                  return $k;
               }
            }
         }
         else {
            return @paths;
         }

         $ret = undef;
      }
   }
   else {
      Rex::Logger::info("Unknown augeas action.");
   }

   Rex::Logger::debug("Augeas Returned: $ret") if $ret;

   return $ret;
}


1;

