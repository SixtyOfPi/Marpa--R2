# Copyright 2013 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

package Marpa::R2::ASF;

use 5.010;
use strict;
use warnings;
no warnings qw(recursion);

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '2.061_002';
$STRING_VERSION = $VERSION;
## no critic(BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic

# The code in this file, for now, breaks "the rules".  It makes use
# of internal methods not documented as part of Libmarpa.
# It is intended to create documented Libmarpa methods to underlie
# this interface, and rewrite it to use them

package Marpa::R2::Internal::ASF;

sub symbol_make {
    my ( $recce, $and_node_id ) = @_;
    my $grammar      = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c    = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage       = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $token_isy_id = $bocage->_marpa_b_and_node_symbol($and_node_id);
    my $token_id     = $grammar_c->_marpa_g_source_xsy($token_isy_id);
    my $value_ix     = $bocage->_marpa_b_and_node_token($and_node_id);
    my $symbol_blessing =
        $recce->[Marpa::R2::Internal::Recognizer::ASF_SYMBOL_BLESSINGS]
        ->[$token_id];
    my $value =
        $recce->[Marpa::R2::Internal::Recognizer::TOKEN_VALUES]->[$value_ix];
    return bless [$value], $symbol_blessing;
} ## end sub symbol_make

sub irl_extend {
    my ( $recce, $or_node_id ) = @_;
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $irl_id    = $bocage->_marpa_b_or_node_irl($or_node_id);
    return or_node_flatten( $recce, $or_node_id )
        if not $grammar_c->_marpa_g_irl_is_virtual_rhs($irl_id);
    my @choices;
    for my $and_node_id ( $bocage->_marpa_b_or_node_first_and($or_node_id)
        .. $bocage->_marpa_b_or_node_last_and($or_node_id) )
    {
        my $predecessor_id =
            $bocage->_marpa_b_and_node_predecessor($and_node_id);

        # If not defined, one choice, an empty series of node ID's
        my $left_choices =
            defined $predecessor_id
            ? or_node_flatten( $recce, $predecessor_id )
            : [ [] ];
        my $cause_id = $bocage->_marpa_b_and_node_cause($and_node_id);
        my $right_choices = irl_extend( $recce, $cause_id );
        for my $left_choice ( @{$left_choices} ) {
            for my $right_choice ( @{$right_choices} ) {
                push @choices, [ @{$left_choice}, @{$right_choice} ];
            }
        }
    } ## end for my $and_node_id ( $bocage->_marpa_b_or_node_first_and...)
    return \@choices;
} ## end sub irl_extend

sub or_node_flatten {
    my ( $recce, $or_node_id ) = @_;
    my $bocage = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my @choices;
    for my $and_node_id ( $bocage->_marpa_b_or_node_first_and($or_node_id)
        .. $bocage->_marpa_b_or_node_last_and($or_node_id) )
    {
        my @choice = ();
        my $proto_choices =
            [ [] ];    # a single empty list of or-node IDs is the default
        my $predecessor_id =
            $bocage->_marpa_b_and_node_predecessor($and_node_id);
        if ( defined $predecessor_id ) {
            $proto_choices = or_node_flatten( $recce, $predecessor_id );
        }
        my $next_choice;
        if (defined(
                my $cause_id = $bocage->_marpa_b_and_node_cause($and_node_id)
            )
            )
        {
            $next_choice = $cause_id;
        } ## end if ( defined( my $cause_id = $bocage...))
        else {
            my $token_id = $bocage->_marpa_b_and_node_symbol($and_node_id);
            $next_choice = symbol_make( $recce, $and_node_id );
        }
        for my $proto_choice ( @{$proto_choices} ) {
            push @choices, [ @{$proto_choice}, $next_choice ];
        }
    } ## end for my $and_node_id ( $bocage->_marpa_b_or_node_first_and...)
    return \@choices;
} ## end sub or_node_flatten

sub or_node_expand {
    my ( $recce, $or_node_id ) = @_;
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $irl_id    = $bocage->_marpa_b_or_node_irl($or_node_id);
    my $xrl_id    = $grammar_c->_marpa_g_source_xrl($irl_id);
    my $rule_blessing =
        $recce->[Marpa::R2::Internal::Recognizer::ASF_RULE_BLESSINGS]
        ->[$xrl_id];
    my $irl_desc = $grammar->brief_irl($irl_id);
    my @children = ();
    my $choices  = irl_extend( $recce, $or_node_id );

    for my $choice ( @{$choices} ) {
        push @children,
            bless [ map { ref $_ ? $_ : or_node_expand( $recce, $_ ) }
                @{$choice} ],
            $rule_blessing;
    } ## end for my $choice ( @{$choices} )
    my $choice_count = scalar @children;
    if ( $choice_count <= 1 ) {
        return $children[0];
    }
    return bless [
        "OR=" . $recce->or_node_tag($or_node_id), $irl_desc,
        ( "choice count = " . scalar @children ), @children
        ],
        $recce->[Marpa::R2::Internal::Recognizer::ASF_CHOICE_CLASS];
} ## end sub or_node_expand

sub normalize_asf_blessing {
    my ($name) = @_;
    $name =~ s/\A \s * //xms;
    $name =~ s/ \s * \z//xms;
    $name =~ s/ \s+ / /gxms;
    $name =~ s/ [^\w] /_/gxms;
    return $name;
} ## end sub normalize_asf_blessing

sub Marpa::R2::Scanless::R::asf {
    my ( $slr, @arg_hashes ) = @_;
    my $slg       = $slr->[Marpa::R2::Inner::Scanless::R::GRAMMAR];
    my $thin_slr  = $slr->[Marpa::R2::Inner::Scanless::R::C];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $recce_c   = $recce->[Marpa::R2::Internal::Recognizer::C];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $choice_blessing = 'My_ASF::choice';
    my $force;

    for my $args (@arg_hashes) {
        if ( defined( my $value = $args->{choice} ) ) {
            $recce->[Marpa::R2::Internal::Recognizer::ASF_CHOICE_CLASS] =
                $choice_blessing = $value;
        }
        if ( defined( my $value = $args->{force} ) ) {
            $force = $value;
        }
    } ## end for my $args (@arg_hashes)

    Marpa::R2::exception(
        q{The "force" named argument must be specified with the $slr->asf() method}
    ) if not defined $force;

    my @rule_blessing   = ();
    my $highest_rule_id = $grammar_c->highest_rule_id();
    for ( my $rule_id = 0; $rule_id <= $highest_rule_id; $rule_id++ ) {
        my $lhs_id = $grammar_c->rule_lhs($rule_id);
        my $name   = Marpa::R2::Grammar::original_symbol_name(
            $grammar->symbol_name($lhs_id) );
        $rule_blessing[$rule_id] = join q{::}, $force,
            normalize_asf_blessing($name);
    } ## end for ( my $rule_id = 0; $rule_id <= $highest_rule_id; ...)
    my @symbol_blessing   = ();
    my $highest_symbol_id = $grammar_c->highest_symbol_id();
    for ( my $symbol_id = 0; $symbol_id <= $highest_symbol_id; $symbol_id++ )
    {
        my $name = Marpa::R2::Grammar::original_symbol_name(
            $grammar->symbol_name($symbol_id) );
        $symbol_blessing[$symbol_id] = join q{::}, $force,
            normalize_asf_blessing($name);
    } ## end for ( my $symbol_id = 0; $symbol_id <= $highest_symbol_id...)
    $recce->[Marpa::R2::Internal::Recognizer::ASF_RULE_BLESSINGS] =
        \@rule_blessing;
    $recce->[Marpa::R2::Internal::Recognizer::ASF_SYMBOL_BLESSINGS] =
        \@symbol_blessing;

    $DB::single = 1;

    # We use the bocage to make sure that conflicting evaluations
    # are not being tried at once
    my $bocage = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    Marpa::R2::exception(
        "Attempt to create an ASF for a recognizer that is already being valued"
    ) if $bocage;
    $grammar_c->throw_set(0);
    $bocage = $recce->[Marpa::R2::Internal::Recognizer::B_C] =
        Marpa::R2::Thin::B->new( $recce_c, -1 );
    $grammar_c->throw_set(1);

    die "No parse" if not defined $bocage;

    my $rule_resolutions =
        $recce->[Marpa::R2::Internal::Recognizer::RULE_RESOLUTIONS] =
        Marpa::R2::Internal::Recognizer::semantics_set( $recce,
        Marpa::R2::Internal::Recognizer::default_semantics($recce) );

    my $augment_or_node_id = $bocage->_marpa_b_top_or_node();
    my $augment_and_node_id =
        $bocage->_marpa_b_or_node_first_and($augment_or_node_id);
    my $augment2_or_node_id =
        $bocage->_marpa_b_and_node_cause($augment_and_node_id);
    my $augment2_and_node_id =
        $bocage->_marpa_b_or_node_first_and($augment2_or_node_id);
    my $start_or_node_id =
        $bocage->_marpa_b_and_node_cause($augment2_and_node_id);
    return \[ or_node_expand( $recce, $start_or_node_id ),
        $recce->show_bocage() ];
} ## end sub Marpa::R2::Scanless::R::asf

1;

# vim: expandtab shiftwidth=4: