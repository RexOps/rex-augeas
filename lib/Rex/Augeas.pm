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
use Rex::Commands::Run;
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
      if($is_ssh) {
      }
      else {
         my $opts = { @options };
         my @lines = run "augtool print /files$file";

         my $new_path = "/files$file/" . scalar(@lines);
         Rex::Logger::debug("New number: " . scalar(@lines));

         if(exists $opts->{"before"}) {
            $aug->insert(scalar(@lines), before => "/files$file" . $opts->{"before"});
            delete $opts->{"before"};
         }
         elsif(exists $opts->{"after"}) {
            my $t = $aug->insert(scalar(@lines), after => "/files$file" . $opts->{"after"});
            delete $opts->{"after"};
         }
         else {
            Rex::Logger::info("Error inserting key. You have to specify before or after.");
            return 0;
         }

         for(my $i=0; $i < @options; $i+=2) {
            my $key = $options[$i];
            my $val = $options[$i+1];

            if($key eq "after" || $key eq "before") {
               next;
            }
            
            my $_key = "/files$file/" . scalar(@lines) . "/$key";
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
   else {
      Rex::Logger::info("Unknown augeas action.");
   }

   Rex::Logger::debug("Augeas Returned: $ret");

   return $ret;
}


1;

