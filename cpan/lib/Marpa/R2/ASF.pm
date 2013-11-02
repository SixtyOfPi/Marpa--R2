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
$VERSION        = '2.075_000';
$STRING_VERSION = $VERSION;
## no critic(BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic

# The code in this file, for now, breaks "the rules".  It makes use
# of internal methods not documented as part of Libmarpa.
# It is intended to create documented Libmarpa methods to underlie
# this interface, and rewrite it to use them

package Marpa::R2::Internal::ASF;

# This is more complicated that it needs to be for the current implementation.
# It allows for LHS terminals (implemented in Libmarpa but not allowed by the SLIF).
# It also assumes that every or-node which can be constructed from preceding or-nodes
# and the input will be present.  This is currently the case, but in the future
# rules and/or symbols may have extra-syntactic conditions attached making this
# assumption false.

# Terms:

# NID (Node ID): Encoded ID of either an or-node or an and-node.
#
# Extensions:
# Set "powers":  A set of power 0 is an "atom" -- a single NID.
# A set of power 1 is a set of NID's -- a nidset.
# A set of power 2 is a set of sets of NID's, also called a powerset.
# A set of power 3 is a set of powersets, etc.
#
# The whole ID of NID is the external rule id of an or-node, or -1
# if the NID is for a token and-node.
#
# Intensions:
# A Symch is a nidset, where all the NID's share the same "whole ID"
# and the same span.  NID's in a symch may differ in their internal rule,
# or have different causes.  If the symch contains and-node NID's they
# will all have the same symbol.
#
# A choicepoint is a powerset -- a set of symches all of which share
# the same set of predecessors.  (This set of predecessors is a power 3 set of
# choicepoints.)  All symches in a choicepoint also share the same span,
# and the same symch-symbol.  A symch's symbol is the LHS of the rule,
# or the symbol of the token in the token and-nodes.

sub intset_id {
    my ( $asf, @ids ) = @_;
    my $key = join q{ }, sort { $a <=> $b } @ids;
    my $intset_by_key =
        $asf->[Marpa::R2::Internal::Scanless::ASF::INTSET_BY_KEY];
    my $intset_id = $intset_by_key->{$key};
    return $intset_id if defined $intset_id;
    $intset_id = $asf->[Marpa::R2::Internal::Scanless::ASF::NEXT_INTSET_ID]++;
    $intset_by_key->{$key} = $intset_id;
    return $intset_id;
} ## end sub intset_id

sub Marpa::R2::Nidset::obtain {
    my ( $class, $asf, @nids ) = @_;
    my $id = intset_id( $asf, @nids );
    my $nidset_by_id =
        $asf->[Marpa::R2::Internal::Scanless::ASF::NIDSET_BY_ID];
    my $nidset = $nidset_by_id->[$id];
    return $nidset if defined $nidset;
    $nidset = bless [], $class;
    $nidset->[Marpa::R2::Internal::Nidset::ID] = $id;
    $nidset->[Marpa::R2::Internal::Nidset::NIDS] =
        [ sort { $a <=> $b } @nids ];
    $nidset_by_id->[$id] = $nidset;
    return $nidset;
} ## end sub Marpa::R2::Nidset::obtain

sub Marpa::R2::Nidset::nids {
    my ($nidset) = @_;
    return $nidset->[Marpa::R2::Internal::Nidset::NIDS];
}

sub Marpa::R2::Nidset::nid {
    my ( $nidset, $ix ) = @_;
    return $nidset->[Marpa::R2::Internal::Nidset::NIDS]->[$ix];
}

sub Marpa::R2::Nidset::count {
    my ($nidset) = @_;
    return scalar @{ $nidset->[Marpa::R2::Internal::Nidset::NIDS] };
}

sub Marpa::R2::Nidset::id {
    my ($nidset) = @_;
    return $nidset->[Marpa::R2::Internal::Nidset::ID];
}

sub Marpa::R2::Nidset::show {
    my ($nidset) = @_;
    my $id       = $nidset->id();
    my $nids     = $nidset->nids();
    return "Nidset #$id: " . join q{ }, @{$nids};
} ## end sub Marpa::R2::Nidset::show

sub Marpa::R2::Powerset::obtain {
    my ( $class, $asf, @nidset_ids ) = @_;
    my $id = intset_id( $asf, @nidset_ids );
    my $powerset_by_id =
        $asf->[Marpa::R2::Internal::Scanless::ASF::POWERSET_BY_ID];
    my $powerset = $powerset_by_id->[$id];
    return $powerset if defined $powerset;
    $powerset = bless [], $class;
    $powerset->[Marpa::R2::Internal::Powerset::ID] = $id;
    $powerset->[Marpa::R2::Internal::Powerset::NIDSET_IDS] =
        [ sort { $a <=> $b } @nidset_ids ];
    $powerset_by_id->[$id] = $powerset;
    return $powerset;
} ## end sub Marpa::R2::Powerset::obtain

sub Marpa::R2::Powerset::nidset_ids {
    my ($powerset) = @_;
    return $powerset->[Marpa::R2::Internal::Powerset::NIDSET_IDS];
}

sub Marpa::R2::Powerset::count {
    my ($powerset) = @_;
    return scalar @{ $powerset->[Marpa::R2::Internal::Powerset::NIDSET_IDS] };
}

sub Marpa::R2::Powerset::nidset_id {
    my ( $powerset, $ix ) = @_;
    my $nidset_ids = $powerset->[Marpa::R2::Internal::Powerset::NIDSET_IDS];
    return if $ix > $#{$nidset_ids};
    return $powerset->[Marpa::R2::Internal::Powerset::NIDSET_IDS]->[$ix];
} ## end sub Marpa::R2::Powerset::nidset_id

sub Marpa::R2::Powerset::id {
    my ($powerset) = @_;
    return $powerset->[Marpa::R2::Internal::Powerset::ID];
}

sub Marpa::R2::Powerset::show {
    my ($powerset) = @_;
    my $id         = $powerset->id();
    my $nidset_ids = $powerset->nidset_ids();
    return "Powerset #$id: " . join q{ }, @{$nidset_ids};
} ## end sub Marpa::R2::Powerset::show

sub set_last_choice {
    my ( $asf, $nook ) = @_;
    my $or_nodes   = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    my $or_node_id = $nook->[Marpa::R2::Internal::Nook::OR_NODE];
    my $and_nodes  = $or_nodes->[$or_node_id];
    my $choice     = $nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE];
    return if $choice > $#{$and_nodes};
    if ( nook_has_semantic_cause( $asf, $nook ) ) {
        my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
        my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
        my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
        my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
        my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
        my $and_node_id = $and_nodes->[$choice];
        my $current_predecessor =
            $bocage->_marpa_b_and_node_predecessor($and_node_id) // -1;
        AND_NODE: while (1) {
            $choice++;
            $and_node_id = $and_nodes->[$choice];
            last AND_NODE if not defined $and_node_id;
            my $next_predecessor =
                $bocage->_marpa_b_and_node_predecessor($and_node_id) // -1;
            last AND_NODE if $current_predecessor != $next_predecessor;
        } ## end AND_NODE: while (1)
        $choice--;
    } ## end if ( nook_has_semantic_cause( $asf, $nook ) )
    $nook->[Marpa::R2::Internal::Nook::LAST_CHOICE] = $choice;
    return $choice;
} ## end sub set_last_choice

sub nook_new {
    my ( $asf, $or_node_id, $parent_or_node_id ) = @_;
    my $nook = [];
    $nook->[Marpa::R2::Internal::Nook::OR_NODE] = $or_node_id;
    $nook->[Marpa::R2::Internal::Nook::PARENT] = $parent_or_node_id // -1;
    $nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE] = 0;
    set_last_choice( $asf, $nook );
    return $nook;
} ## end sub nook_new

sub nook_increment {
    my ( $asf, $nook ) = @_;
    $nook->[Marpa::R2::Internal::Nook::LAST_CHOICE] //= 0;
    $nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE] =
        $nook->[Marpa::R2::Internal::Nook::LAST_CHOICE] + 1;
    return if not defined set_last_choice( $asf, $nook );
    return 1;
} ## end sub nook_increment

sub nook_has_semantic_cause {
    my ( $asf, $nook ) = @_;
    my $or_node   = $nook->[Marpa::R2::Internal::Nook::OR_NODE];
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];

    my $irl_id          = $bocage->_marpa_b_or_node_irl($or_node);
    my $predot_position = $bocage->_marpa_b_or_node_position($or_node) - 1;
    my $predot_isyid =
        $grammar_c->_marpa_g_irl_rhs( $irl_id, $predot_position );
    return $grammar_c->_marpa_g_isy_is_semantic($predot_isyid);
} ## end sub nook_has_semantic_cause

# No check for conflicting usage -- value(), asf(), etc.
# at this point
sub Marpa::R2::Scanless::ASF::top {
    my ($asf) = @_;
    my $top = $asf->[Marpa::R2::Internal::Scanless::ASF::TOP];
    return $top if defined $top;
    my $or_nodes = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    my $slr      = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce    = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];

    my $bocage = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    die 'No Bocage' if not $bocage;
    my $augment_or_node_id  = $bocage->_marpa_b_top_or_node();
    my $augment_and_node_id = $or_nodes->[$augment_or_node_id]->[0];
    my $start_or_node_id =
        $bocage->_marpa_b_and_node_cause($augment_and_node_id);

    my $top_nidset = Marpa::R2::Nidset->obtain( $asf, $start_or_node_id );
    my $top_choicepoint_base =
        nidset_to_choicepoint_base( $asf, $top_nidset );
    $top = $asf->new_choicepoint($top_choicepoint_base);

    $asf->[Marpa::R2::Internal::Scanless::ASF::TOP] = $top;
    return $top;
} ## end sub Marpa::R2::Scanless::ASF::top

# Range from -1 to -42 reserved for special values
sub and_node_to_nid { return -$_[0] - 43; }
sub nid_to_and_node { return -$_[0] - 43; }

sub normalize_asf_blessing {
    my ($name) = @_;
    $name =~ s/\A \s * //xms;
    $name =~ s/ \s * \z//xms;
    $name =~ s/ \s+ / /gxms;
    $name =~ s/ \W /_/gxms;
    return $name;
} ## end sub normalize_asf_blessing

sub Marpa::R2::Internal::ASF::blessings_set {
    my ( $asf, $default_blessing, $force ) = @_;
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $rules    = $grammar->[Marpa::R2::Internal::Grammar::RULES];
    my $symbols  = $grammar->[Marpa::R2::Internal::Grammar::SYMBOLS];

    my $default_token_blessing_package =
        $asf
        ->[Marpa::R2::Internal::Scanless::ASF::DEFAULT_TOKEN_BLESSING_PACKAGE
        ];
    my $default_rule_blessing_package = $asf
        ->[Marpa::R2::Internal::Scanless::ASF::DEFAULT_RULE_BLESSING_PACKAGE];

    my @rule_blessing   = ();
    my $highest_rule_id = $grammar_c->highest_rule_id();
    RULE: for ( my $rule_id = 0; $rule_id <= $highest_rule_id; $rule_id++ ) {
        my $blessing;
        my $rule     = $rules->[$rule_id];
        $blessing = $rule->[Marpa::R2::Internal::Rule::BLESSING] if defined $rule;
        if ( q{::} ne substr $blessing, 0, 2 ) {
            $rule_blessing[$rule_id] = $blessing;
            next RULE;
        }
        my $lhs_id = $grammar_c->rule_lhs($rule_id);
        my $name   = $grammar->symbol_name($lhs_id);
        $rule_blessing[$rule_id] = join q{::}, $default_rule_blessing_package,
            normalize_asf_blessing($name);
    } ## end RULE: for ( my $rule_id = 0; $rule_id <= $highest_rule_id; ...)

    my @symbol_blessing   = ();
    my $highest_symbol_id = $grammar_c->highest_symbol_id();
    SYMBOL:
    for ( my $symbol_id = 0; $symbol_id <= $highest_symbol_id; $symbol_id++ )
    {
        my $blessing;
        my $symbol     = $symbols->[$symbol_id];
        $blessing = $symbol->[Marpa::R2::Internal::Symbol::BLESSING] if defined $symbol;
        if ( q{::} ne substr $blessing, 0, 2 ) {
            $symbol_blessing[$symbol_id] = $blessing;
            next SYMBOL;
        }
        my $name = $grammar->symbol_name($symbol_id);
        $symbol_blessing[$symbol_id] = join q{::}, $default_token_blessing_package,
                normalize_asf_blessing($name);
    } ## end SYMBOL: for ( my $symbol_id = 0; $symbol_id <= $highest_symbol_id...)
    $asf->[Marpa::R2::Internal::Scanless::ASF::RULE_BLESSINGS] =
        \@rule_blessing;
    $asf->[Marpa::R2::Internal::Scanless::ASF::SYMBOL_BLESSINGS] =
        \@symbol_blessing;
    return $asf;
} ## end sub Marpa::R2::Internal::ASF::blessings_set

# Returns undef if no parse
sub Marpa::R2::Scanless::ASF::new {
    my ( $class, @arg_hashes ) = @_;
    my $asf = bless [], $class;

    my $slr;

    for my $arg_hash (@arg_hashes) {
        ARG: for my $arg ( keys %{$arg_hash} ) {
            if ( $arg eq 'slr' ) {
                $asf->[Marpa::R2::Internal::Scanless::ASF::SLR] = $slr =
                    $arg_hash->{$arg};
                next ARG;
            }
            Marpa::R2::exception(
                qq{Unknown named arg to $asf->new(): "$arg"});
        } ## end ARG: for my $arg ( keys %{$arg_hash} )
    } ## end for my $arg_hash (@arg_hashes)

    Marpa::R2::exception(
        q{The "slr" named argument must be specified with the Marpa::R2::Scanless::ASF::new method}
    ) if not defined $slr;
    $asf->[Marpa::R2::Internal::Scanless::ASF::SLR] = $slr;

    my $recce = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];

    if ( defined $recce->[Marpa::R2::Internal::Recognizer::TREE_MODE] ) {

        # If we already in ASF mode, or are in valuation mode, we cannot create an ASF
        Marpa::R2::exception(
            "An attempt was made to create an ASF for a SLIF recognizer already in use\n",
            "   The recognizer must be reset first\n",
            '  The current SLIF recognizer mode is "',
            $recce->[Marpa::R2::Internal::Recognizer::TREE_MODE],
            qq{"\n}
        );
    } ## end if ( defined $recce->[Marpa::R2::Internal::Recognizer::TREE_MODE...])
    $recce->[Marpa::R2::Internal::Recognizer::TREE_MODE] = 'forest';

    $asf->[Marpa::R2::Internal::Scanless::ASF::SYMCH_BLESSING_PACKAGE] = 'My_Symch';
    $asf->[Marpa::R2::Internal::Scanless::ASF::FACTORING_BLESSING_PACKAGE] = 'My_Factoring';
    $asf->[Marpa::R2::Internal::Scanless::ASF::PROBLEM_BLESSING_PACKAGE] = 'My_Problem';
    $asf->[Marpa::R2::Internal::Scanless::ASF::DEFAULT_RULE_BLESSING_PACKAGE] = 'My_Rule';
    $asf->[Marpa::R2::Internal::Scanless::ASF::DEFAULT_TOKEN_BLESSING_PACKAGE] = 'My_Token';

    $asf->[Marpa::R2::Internal::Scanless::ASF::NEXT_INTSET_ID] = 0;
    $asf->[Marpa::R2::Internal::Scanless::ASF::INTSET_BY_KEY]  = {};

    $asf->[Marpa::R2::Internal::Scanless::ASF::NIDSET_BY_ID]   = [];
    $asf->[Marpa::R2::Internal::Scanless::ASF::POWERSET_BY_ID] = [];

    my $slg       = $slr->[Marpa::R2::Inner::Scanless::R::GRAMMAR];
    my $thin_slr  = $slr->[Marpa::R2::Inner::Scanless::R::C];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $recce_c   = $recce->[Marpa::R2::Internal::Recognizer::C];

    $recce->ordering_create()
        if not $recce->[Marpa::R2::Internal::Recognizer::O_C];

    my $bocage   = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $ordering = $recce->[Marpa::R2::Internal::Recognizer::O_C];
    Marpa::R2::exception(
        "An attempt was make to create an ASF for a null parse\n",
        "  A null parse is a successful parse of a zero-length string\n",
        "  ASF's are not defined for null parses\n"
    ) if $ordering->is_null();

    my $or_nodes = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES] = [];
    use sort 'stable';
    OR_NODE: for ( my $or_node_id = 0;; $or_node_id++ ) {
        my @and_node_ids =
            $ordering->_marpa_o_or_node_and_node_ids($or_node_id);
        last OR_NODE if not scalar @and_node_ids;
        my @sorted_and_node_ids = map { $_->[-1] } sort { $a <=> $b } map {
            [ ( $bocage->_marpa_b_and_node_predecessor($_) // -1 ), $_ ]
        } @and_node_ids;
        $or_nodes->[$or_node_id] = \@and_node_ids;
    } ## end OR_NODE: for ( my $or_node_id = 0;; $or_node_id++ )

    return $asf;

} ## end sub Marpa::R2::Scanless::ASF::new

sub Marpa::R2::Scanless::ASF::new_choicepoint {
    my ( $asf, $powerset ) = @_;
    my $cp = bless [], 'Marpa::R2::Choicepoint';
    $cp->[Marpa::R2::Internal::Choicepoint::ASF]             = $asf;
    $cp->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK] = undef;
    $cp->[Marpa::R2::Internal::Choicepoint::POWERSET]        = $powerset;
    $cp->[Marpa::R2::Internal::Choicepoint::SYMCH_IX]        = 0;
    $cp->[Marpa::R2::Internal::Choicepoint::NID_IX]          = 0;
    return $cp;
} ## end sub Marpa::R2::Scanless::ASF::new_choicepoint

sub nid_sort_ix {
    my ( $asf, $nid ) = @_;
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    if ( $nid >= 0 ) {
        my $irl_id = $bocage->_marpa_b_or_node_irl($nid);
        return $grammar_c->_marpa_g_source_xrl($irl_id);
    }
    my $and_node_id  = nid_to_and_node($nid);
    my $token_isy_id = $bocage->_marpa_b_and_node_symbol($and_node_id);
    my $token_id     = $grammar_c->_marpa_g_source_xsy($token_isy_id);

    # -2 is reserved for 'end of data'
    return -$token_id - 3;
} ## end sub nid_sort_ix

sub nidset_to_choicepoint_base {
    my ( $asf, $nidset ) = @_;

    # Memoize this method?
    my @source_data = ();
    for my $source_nid ( @{ $nidset->nids() } ) {
        my $sort_ix = nid_sort_ix( $asf, $source_nid );
        push @source_data, [ $sort_ix, $source_nid ];
    }
    my @sorted_source_data = sort { $a->[0] <=> $b->[0] } @source_data;
    my $nid_ix = 0;
    my ( $sort_ix_of_this_nid, $this_nid ) =
        @{ $sorted_source_data[ $nid_ix++ ] };
    my @nids_with_current_sort_ix = ();
    my $current_sort_ix           = $sort_ix_of_this_nid;
    my @symch_ids                 = ();
    NID: while (1) {

        if ( $sort_ix_of_this_nid != $current_sort_ix ) {

            # Currently only whole id break logic
            my $nidset_for_sort_ix =
                Marpa::R2::Nidset->obtain( $asf, @nids_with_current_sort_ix );
            push @symch_ids, $nidset_for_sort_ix->id();
            @nids_with_current_sort_ix = ();
            $current_sort_ix           = $sort_ix_of_this_nid;
        } ## end if ( $sort_ix_of_this_nid != $current_sort_ix )
        last NID if not defined $this_nid;
        push @nids_with_current_sort_ix, $this_nid;
        my $sorted_entry = $sorted_source_data[ $nid_ix++ ];
        if ( defined $sorted_entry ) {
            ( $sort_ix_of_this_nid, $this_nid ) = @{$sorted_entry};
            next NID;
        }
        $this_nid            = undef;
        $sort_ix_of_this_nid = -2;
    } ## end NID: while (1)
    return Marpa::R2::Powerset->obtain( $asf, @symch_ids );
} ## end sub nidset_to_choicepoint_base

sub Marpa::R2::Choicepoint::show {
    my ($cp) = @_;
    my $id = $cp->base_id();
    return join q{ }, "Choicepoint based on powerset #$id: ",
        $cp->[Marpa::R2::Internal::Choicepoint::POWERSET]->show();
} ## end sub Marpa::R2::Choicepoint::show

sub Marpa::R2::Choicepoint::grammar {
    my ($choicepoint) = @_;
    my $asf           = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $slr           = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce         = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar       = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    return $grammar;
} ## end sub Marpa::R2::Choicepoint::grammar

# ID of the set on which the choicepoint is based.  Two or more choicepoints
# may share the same base ID.
sub Marpa::R2::Choicepoint::base_id {
    my ($cp) = @_;
    return $cp->[Marpa::R2::Internal::Choicepoint::POWERSET]->id();
}

sub Marpa::R2::Choicepoint::symch_count {
    my ($cp) = @_;
    return $cp->[Marpa::R2::Internal::Choicepoint::POWERSET]->count();
}

sub Marpa::R2::Choicepoint::symch {
    my ( $cp, $symch_ix ) = @_;
    $symch_ix //= $cp->[Marpa::R2::Internal::Choicepoint::SYMCH_IX];
    my $asf = $cp->[Marpa::R2::Internal::Choicepoint::ASF];
    my $nidset_by_id =
        $asf->[Marpa::R2::Internal::Scanless::ASF::NIDSET_BY_ID];
    my $symch_id =
        $cp->[Marpa::R2::Internal::Choicepoint::POWERSET]
        ->nidset_id($symch_ix);
    return $nidset_by_id->[$symch_id];
} ## end sub Marpa::R2::Choicepoint::symch

sub Marpa::R2::Choicepoint::nid_count {
    my ($choicepoint) = @_;
    my $symch = $choicepoint->symch();
    return $symch->count();
}

sub Marpa::R2::Choicepoint::nid_set {
    my ( $choicepoint, $nid_ix ) = @_;
    my $nid_count = $choicepoint->nid_count();
    return if $nid_ix >= $nid_count;
    if ( $nid_ix < 0 ) {
        Marpa::R2::exception(
            "Invalid attempt to set the NID ix of a choicepoint to $nid_ix\n",
        );
    }
    $choicepoint->[Marpa::R2::Internal::Choicepoint::NID_IX] = $nid_ix;
    return 1;
} ## end sub Marpa::R2::Choicepoint::nid_set

sub Marpa::R2::Choicepoint::nid {
    my ( $cp, $symch_ix, $nid_ix ) = @_;
    $symch_ix //= $cp->[Marpa::R2::Internal::Choicepoint::SYMCH_IX];
    $nid_ix   //= $cp->[Marpa::R2::Internal::Choicepoint::NID_IX];
    my $symch = $cp->symch($symch_ix);
    return if not defined $symch;
    return $symch->nid($nid_ix);
} ## end sub Marpa::R2::Choicepoint::nid

sub Marpa::R2::Choicepoint::symch_set {
    my ( $cp, $ix ) = @_;
    Marpa::R2::exception('SYMCH index less than 0') if $ix < 0;
    return if $ix >= $cp->symch_count();
    $cp->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK] = undef;
    $cp->[Marpa::R2::Internal::Choicepoint::NID_IX]          = 0;
    $cp->[Marpa::R2::Internal::Choicepoint::SYMCH_IX] = $ix;
    return 1;
} ## end sub Marpa::R2::Choicepoint::symch_set

sub Marpa::R2::Choicepoint::rule_id {
    my ($cp) = @_;
    my $asf = $cp->[Marpa::R2::Internal::Choicepoint::ASF];
    my $or_node_id = $cp->nid() // -1;
    return nid_to_whole_id( $asf, $or_node_id );
} ## end sub Marpa::R2::Choicepoint::rule_id

# The "whole id" is the external rule ID, if there is one,
# otherwise -1.  In particular, it is -1 is the NID is for
# token
sub nid_to_whole_id {
    my ( $asf, $nid ) = @_;
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    return -1 if $nid < 0;
    my $irl_id = $bocage->_marpa_b_or_node_irl($nid);
    my $xrl_id = $grammar_c->_marpa_g_source_xrl($irl_id);
    return $xrl_id;
} ## end sub nid_to_whole_id

sub or_node_es_span {
    my ( $asf, $choicepoint ) = @_;
    my $slr        = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce      = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $bocage     = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $origin_es  = $bocage->_marpa_b_or_node_origin($choicepoint);
    my $current_es = $bocage->_marpa_b_or_node_set($choicepoint);
    return $origin_es, $current_es - $origin_es;
} ## end sub or_node_es_span

sub token_es_span {
    my ( $asf, $and_node_id ) = @_;
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $predecessor_id = $bocage->_marpa_b_and_node_predecessor($and_node_id);
    my $parent_or_node_id = $bocage->_marpa_b_and_node_parent($and_node_id);

    if ( defined $predecessor_id ) {
        my $origin_es  = $bocage->_marpa_b_or_node_set($predecessor_id);
        my $current_es = $bocage->_marpa_b_or_node_set($parent_or_node_id);
        return ( $origin_es, $current_es - $origin_es );
    }
    return or_node_es_span( $asf, $parent_or_node_id );
} ## end sub token_es_span

sub Marpa::R2::Choicepoint::literal {
    my ($cp) = @_;
    my $nid  = $cp->nid();
    my $asf  = $cp->[Marpa::R2::Internal::Choicepoint::ASF];
    my $slr  = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    if ( $nid < 0 ) {
        my $and_node_id = nid_to_and_node($nid);
        my ( $start, $length ) = token_es_span( $asf, $and_node_id );
        return q{} if $length == 0;
        return $slr->substring( $start, $length );
    } ## end if ( $nid < 0 )
    return $slr->substring( or_node_es_span( $asf, $nid ) );
} ## end sub Marpa::R2::Choicepoint::literal

sub Marpa::R2::Choicepoint::symbol_id {
    my ($cp)      = @_;
    my $nid_0     = $cp->nid(0);
    my $asf       = $cp->[Marpa::R2::Internal::Choicepoint::ASF];
    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    if ( $nid_0 < 0 ) {
        my $and_node_id  = nid_to_and_node($nid_0);
        my $token_isy_id = $bocage->_marpa_b_and_node_symbol($and_node_id);
        my $token_id     = $grammar_c->_marpa_g_source_xsy($token_isy_id);
        return $token_id;
    } ## end if ( $nid_0 < 0 )
    my $irl_id = $bocage->_marpa_b_or_node_irl($nid_0);
    my $xrl_id = $grammar_c->_marpa_g_source_xrl($irl_id);
    my $lhs_id = $grammar_c->rule_lhs($xrl_id);
    return $lhs_id;
} ## end sub Marpa::R2::Choicepoint::symbol_id

sub Marpa::R2::Choicepoint::symbol_name {
    my ($choicepoint) = @_;
    my $asf           = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $slr           = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce         = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar       = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $symbol_id     = $choicepoint->symbol_id();
    return $grammar->symbol_name($symbol_id);
} ## end sub Marpa::R2::Choicepoint::symbol_name

# Memoization is heavily used -- it needs to be to keep the worst cases from
# going exponential.  The need to memoize is the reason for the very heavy use of
# hashes.  For example, quite often an HOH (hash of hashes) is used where
# an HoL (hash of lists) would usually be preferred.  But the HOL would leave me
# with the problem of having duplicates, which if followed up upon, would make
# the algorithm go exponential.

# For the "seen" hashes, the intent, in C, is to use a bit vector.  Since typically
# choicepoints will only use a tiny fraction of the or- and and-node space, I'll create
# a per-choicepoint index in the bit vector for each or- and and-node.  The index will
# per-ASF, and to avoid the overhead of clearing it, it will track, or each node, the
# current CP indexing it.  It is assumed that the indexes need only remain valid within
# the method call that constructs the CPI (choicepoint iterator).

sub Marpa::R2::Choicepoint::first_factoring {
    my ($choicepoint) = @_;

    # Current NID of current SYMCH
    # The caller should ensure that we are never called unless the current
    # NID is for a rule.
    my $nid_of_choicepoint = $choicepoint->nid();
    Marpa::exception(
        "Internal error: next_factoring() called for negative NID: $nid_of_choicepoint"
    ) if $nid_of_choicepoint < 0;

    # Due to skipping, even the top or-node can have no valid choices
    my $asf      = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $or_nodes = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    if ( not scalar @{ $or_nodes->[$nid_of_choicepoint] } ) {
        $choicepoint->[Marpa::R2::Internal::Choicepoint::IS_EXHAUSTED] = 1;
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK] =
            undef;
        return;
    } ## end if ( not scalar @{ $or_nodes->[$nid_of_choicepoint] ...})

    $choicepoint->[Marpa::R2::Internal::Choicepoint::OR_NODE_IN_USE]
        ->{$nid_of_choicepoint} = 1;
    my $nook = nook_new( $asf, $nid_of_choicepoint );
    $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK] =
        [$nook];

    # Iterate as long as we cannot finish this stack
    while ( not factoring_finish($choicepoint) ) {
        return if not factoring_iterate($choicepoint);
    }
    return 1;

} ## end sub Marpa::R2::Choicepoint::first_factoring

sub Marpa::R2::Choicepoint::next_factoring {
    my ($choicepoint) = @_;
    my $factoring_stack =
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK];
    Marpa::R2::exception(
        'Attempt to iterate factoring of uninitialized checkpoint')
        if not $factoring_stack;

    while ( factoring_iterate($choicepoint) ) {
        return 1 if factoring_finish($choicepoint);
    }

    # Found nothing to iterate
    return;
} ## end sub Marpa::R2::Choicepoint::next_factoring

sub factoring_iterate {
    my ($choicepoint) = @_;
    my $asf = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $factoring_stack =
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK];
    FIND_NODE_TO_ITERATE: while (1) {
        if ( not scalar @{$factoring_stack} ) {
            $choicepoint->[Marpa::R2::Internal::Choicepoint::IS_EXHAUSTED] =
                1;
            $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK]
                = undef;
            return;
        } ## end if ( not scalar @{$factoring_stack} )
        my $top_nook = $factoring_stack->[-1];
        if ( nook_increment( $asf, $top_nook ) ) {
            last FIND_NODE_TO_ITERATE;    # in C, a "break" will do this
        }

        # Could not iterate
        # "Dirty" the corresponding bits in the parent and pop this nook
        my $stack_ix_of_parent_nook =
            $top_nook->[Marpa::R2::Internal::Nook::PARENT];
        if ( $stack_ix_of_parent_nook >= 0 ) {
            my $parent_nook = $factoring_stack->[$stack_ix_of_parent_nook];
            $parent_nook->[Marpa::R2::Internal::Nook::CAUSE_IS_EXPANDED] = 0
                if $top_nook->[Marpa::R2::Internal::Nook::IS_CAUSE];
            $parent_nook->[Marpa::R2::Internal::Nook::PREDECESSOR_IS_EXPANDED]
                = 0
                if $top_nook->[Marpa::R2::Internal::Nook::IS_PREDECESSOR];
        } ## end if ( $stack_ix_of_parent_nook >= 0 )

        my $top_or_node = $top_nook->[Marpa::R2::Internal::Nook::OR_NODE];
        $choicepoint->[Marpa::R2::Internal::Choicepoint::OR_NODE_IN_USE]
            ->{$top_or_node} = undef;
        pop @{$factoring_stack};
    } ## end FIND_NODE_TO_ITERATE: while (1)
    return 1;
} ## end sub factoring_iterate

sub factoring_finish {
    my ($choicepoint) = @_;
    my $asf           = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $or_nodes      = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    my $factoring_stack =
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK];

    # Current NID of current SYMCH
    my $nid_of_choicepoint = $choicepoint->nid();

    my $nidset_by_id =
        $asf->[Marpa::R2::Internal::Scanless::ASF::NIDSET_BY_ID];
    my $powerset_by_id =
        $asf->[Marpa::R2::Internal::Scanless::ASF::POWERSET_BY_ID];

    my $slr       = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce     = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar   = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage    = $recce->[Marpa::R2::Internal::Recognizer::B_C];

    my @worklist = ( 0 .. $#{$factoring_stack} );

    DO_WORKLIST: while ( scalar @worklist ) {
        my $stack_ix_of_work_nook = $worklist[-1];
        my $work_nook    = $factoring_stack->[$stack_ix_of_work_nook];
        my $work_or_node = $work_nook->[Marpa::R2::Internal::Nook::OR_NODE];
        my $working_choice =
            $work_nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE];
        my $work_and_node_id = $or_nodes->[$work_or_node]->[$working_choice];
        my $child_or_node;
        my $child_is_cause;
        my $child_is_predecessor;
        FIND_CHILD_OR_NODE: {

            if ( !$work_nook->[Marpa::R2::Internal::Nook::CAUSE_IS_EXPANDED] )
            {
                if ( not nook_has_semantic_cause( $asf, $work_nook ) ) {
                    $child_or_node =
                        $bocage->_marpa_b_and_node_cause($work_and_node_id);
                    $child_is_cause = 1;
                    last FIND_CHILD_OR_NODE;
                } ## end if ( not nook_has_semantic_cause( $asf, $work_nook ))
            } ## end if ( !$work_nook->[...])
            $work_nook->[Marpa::R2::Internal::Nook::CAUSE_IS_EXPANDED] = 1;
            if ( !$work_nook
                ->[Marpa::R2::Internal::Nook::PREDECESSOR_IS_EXPANDED] )
            {
                $child_or_node =
                    $bocage->_marpa_b_and_node_predecessor($work_and_node_id);
                if ( defined $child_or_node ) {
                    $child_is_predecessor = 1;
                    last FIND_CHILD_OR_NODE;
                }
            } ## end if ( !$work_nook->[...])
            $work_nook->[Marpa::R2::Internal::Nook::PREDECESSOR_IS_EXPANDED] =
                1;
            pop @worklist;
            next DO_WORKLIST;
        } ## end FIND_CHILD_OR_NODE:

        return 0
            if
            $choicepoint->[Marpa::R2::Internal::Choicepoint::OR_NODE_IN_USE]
                ->{$child_or_node};

        return 0
            if not scalar @{ $or_nodes->[$work_or_node] };

        my $new_nook =
            nook_new( $asf, $child_or_node, $stack_ix_of_work_nook );
        if ($child_is_cause) {
            $new_nook->[Marpa::R2::Internal::Nook::IS_CAUSE]           = 1;
            $work_nook->[Marpa::R2::Internal::Nook::CAUSE_IS_EXPANDED] = 1;
        }
        if ($child_is_predecessor) {
            $new_nook->[Marpa::R2::Internal::Nook::IS_PREDECESSOR] = 1;
            $work_nook->[Marpa::R2::Internal::Nook::PREDECESSOR_IS_EXPANDED] =
                1;
        }
        push @{$factoring_stack}, $new_nook;
        push @worklist, $#{$factoring_stack};

    } ## end DO_WORKLIST: while ( scalar @worklist )

    return 1;

} ## end sub factoring_finish

sub and_nodes_to_cause_nids {
    my ( $asf, @and_node_ids ) = @_;
    my $slr    = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce  = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $bocage = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my %causes = ();
    for my $and_node_id (@and_node_ids) {
        my $cause_nid = $bocage->_marpa_b_and_node_cause($and_node_id)
            // and_node_to_nid($and_node_id);
        $causes{$cause_nid} = 1;
    }
    return [ keys %causes ];
} ## end sub and_nodes_to_cause_nids

sub Marpa::R2::Choicepoint::factors {
    my ($choicepoint) = @_;
    my $asf           = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $slr           = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce         = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $grammar       = $recce->[Marpa::R2::Internal::Recognizer::GRAMMAR];
    my $grammar_c     = $grammar->[Marpa::R2::Internal::Grammar::C];
    my $bocage        = $recce->[Marpa::R2::Internal::Recognizer::B_C];
    my $or_nodes      = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];

    my @result;
    my $factoring_stack =
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK];
    return if not $factoring_stack;
    FACTOR:
    for (
        my $factor_ix = 0;
        $factor_ix <= $#{$factoring_stack};
        $factor_ix++
        )
    {
        my $nook = $factoring_stack->[$factor_ix];
        next FACTOR if not nook_has_semantic_cause( $asf, $nook );
        my $or_node    = $nook->[Marpa::R2::Internal::Nook::OR_NODE];
        my $and_nodes  = $or_nodes->[$or_node];
        my $cause_nids = and_nodes_to_cause_nids(
            $asf,
            map { $and_nodes->[$_] } (
                $nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE]
                    .. $nook->[Marpa::R2::Internal::Nook::LAST_CHOICE]
            )
        );
        my $choicepoint_nidset =
            Marpa::R2::Nidset->obtain( $asf, @{$cause_nids} );
        my $choicepoint_base =
            nidset_to_choicepoint_base( $asf, $choicepoint_nidset );
        my $new_choicepoint = $asf->new_choicepoint($choicepoint_base);
        push @result, $new_choicepoint;
    } ## end FACTOR: for ( my $factor_ix = 0; $factor_ix <= $#{...})
    return \@result;
} ## end sub Marpa::R2::Choicepoint::factors

sub choicepoint_forest {
    my ( $asf, $choicepoint ) = @_;
    my $base_id = $choicepoint->base_id();
    my $memoized_node =
        $asf->[Marpa::R2::Internal::Scanless::ASF::ASF_NODES]
        ->[$base_id];
    return $memoized_node if defined $memoized_node;
    my @symch_nodes = ();
    for ( my $symch_ix = 0; $choicepoint->symch_set($symch_ix); $symch_ix++ )
    {
        my $rule_id = $choicepoint->rule_id();
        if ( $rule_id >= 0 ) {
            my @factoring_nodes = ();
            FACTORING_NODES: for ( my $nid_ix = 0; $choicepoint->nid_set($nid_ix); $nid_ix++ )
            {

                $choicepoint->first_factoring();
                my $factoring = $choicepoint->factors();
                FACTOR: while ( defined $factoring ) {
                    my @choicepoint_nodes = ();
                    for (
                        my $item_ix = $#{$factoring};
                        $item_ix >= 0;
                        $item_ix--
                        )
                    {
                        my $item_choicepoint = $factoring->[$item_ix];
			push @choicepoint_nodes, choicepoint_forest($asf, $item_choicepoint);
                    } ## end for ( my $item_ix = $#{$factoring}; $item_ix >= 0; ...)
                    $choicepoint->next_factoring();
                    $factoring = $choicepoint->factors();
                    push @factoring_nodes, \@choicepoint_nodes;
                    if (scalar @factoring_nodes > 42) {
                          push @factoring_nodes,
                          bless ["More than 42 factoring"], $asf->[Marpa::R2::Internal::Scanless::ASF::PROBLEM_BLESSING_PACKAGE];
                          last FACTORING_NODES;
                    }
                } ## end FACTOR: while ( defined $factoring )
            } ## end for ( my $nid_ix = 0; $choicepoint->nid_set($nid_ix);...)
            my $symch_node;
            if ( scalar @factoring_nodes > 1 ) {
                $symch_node = bless \@factoring_nodes,
                    $asf->[
                    Marpa::R2::Internal::Scanless::ASF::FACTORING_BLESSING_PACKAGE
                    ];
            } ## end if ( scalar @factoring_nodes > 1 )
            else {
                $symch_node = $factoring_nodes[0];
            }
            push @symch_nodes, $symch_node;
        } ## end if ( $rule_id >= 0 )
        else {
	    for ( my $nid_ix = 0; $choicepoint->nid_set($nid_ix); $nid_ix++ ) {
		my $literal     = $choicepoint->literal();
		my $symbol_name = $choicepoint->symbol_name();
		push @symch_nodes, qq{Symbol: $symbol_name "$literal"};
	    }
        }
    } ## end for ( my $symch_ix = 0; $choicepoint->symch_set($symch_ix...))
    my $choicepoint_node;
    if ( scalar @symch_nodes > 1 ) {
        $choicepoint_node = bless \@symch_nodes, 
    $asf->[Marpa::R2::Internal::Scanless::ASF::SYMCH_BLESSING_PACKAGE];
    }
    else {
        $choicepoint_node = $symch_nodes[0];
    }
    $asf->[Marpa::R2::Internal::Scanless::ASF::ASF_NODES]->[$base_id] =
        $choicepoint_node;
    return $choicepoint_node;
}

sub Marpa::R2::Scanless::ASF::forest {
    my ($asf, @hash_args) = @_;
    my $top = $asf->top();
    return choicepoint_forest($asf, $top);
}

# Return the size of the choicepoint ambiguous prefix.
# This is the last point in the factoring stack with an ambiguity.
# if the choicepoint is ambiguous, it is greater than 0.
# If the choicepoint is unambiguous, it is always 0.
# The concept of "point in the factoring stack" is internal.
sub Marpa::R2::Choicepoint::ambiguous_prefix {
    my ($choicepoint) = @_;
    my $asf           = $choicepoint->[Marpa::R2::Internal::Choicepoint::ASF];
    my $or_nodes      = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    my $slr           = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $recce         = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $bocage        = $recce->[Marpa::R2::Internal::Recognizer::B_C];

    my $factoring_stack =
        $choicepoint->[Marpa::R2::Internal::Choicepoint::FACTORING_STACK];
    Marpa::R2::exception('ASF choicepoint factoring was never initialized')
        if not defined $factoring_stack;
    STACK_POS:
    for (
        my $stack_pos = $#{$factoring_stack};
        $stack_pos >= 0;
        $stack_pos--
        )
    {
        my $nook      = $factoring_stack->[$stack_pos];
        my $or_node   = $nook->[Marpa::R2::Internal::Nook::OR_NODE];
        my $and_nodes = $or_nodes->[$or_node];
        next STACK_POS if scalar @{$and_nodes} <= 1;
        FIND_AMBIGUITY: {
            last FIND_AMBIGUITY if not nook_has_semantic_cause( $asf, $nook );
            my $first_predecessor =
                $bocage->_marpa_b_and_node_predecessor( $and_nodes->[0] )
                // -1;
            for my $and_node_id ( @{$and_nodes}[ 1 .. $#{$and_nodes} ] ) {
                last FIND_AMBIGUITY
                    if $first_predecessor
                    != ( $bocage->_marpa_b_and_node_predecessor($and_node_id)
                        // -1 );
            } ## end for my $and_node_id ( @{$and_nodes}[ 1 .. $#{$and_nodes...}])
            next STACK_POS;
        } ## end FIND_AMBIGUITY:
        return $stack_pos + 1;
    } ## end STACK_POS: for ( my $stack_pos = $#{$factoring_stack}; $stack_pos...)
    return 0;
} ## end sub Marpa::R2::Choicepoint::ambiguous_prefix

sub Marpa::R2::Scanless::ASF::show_nidsets {
    my ($asf)   = @_;
    my $text    = q{};
    my $nidsets = $asf->[Marpa::R2::Internal::Scanless::ASF::NIDSET_BY_ID];
    for my $nidset ( grep {defined} @{$nidsets} ) {
        $text .= $nidset->show() . "\n";
    }
    return $text;
} ## end sub Marpa::R2::Scanless::ASF::show_nidsets

sub Marpa::R2::Scanless::ASF::show_powersets {
    my ($asf) = @_;
    my $text = q{};
    my $powersets =
        $asf->[Marpa::R2::Internal::Scanless::ASF::POWERSET_BY_ID];
    for my $powerset ( grep {defined} @{$powersets} ) {
        $text .= $powerset->show() . "\n";
    }
    return $text;
} ## end sub Marpa::R2::Scanless::ASF::show_powersets

sub dump_nook {
    my ( $asf, $nook ) = @_;
    my $slr        = $asf->[Marpa::R2::Internal::Scanless::ASF::SLR];
    my $or_nodes   = $asf->[Marpa::R2::Internal::Scanless::ASF::OR_NODES];
    my $recce      = $slr->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $or_node_id = $nook->[Marpa::R2::Internal::Nook::OR_NODE];
    my $and_node_count = scalar @{ $or_nodes->[$or_node_id] };
    my $text           = 'Nook ';
    my @text           = ();
    push @text, $nook->[Marpa::R2::Internal::Nook::IS_CAUSE] ? q{C} : q{-};
    push @text,
        $nook->[Marpa::R2::Internal::Nook::IS_PREDECESSOR] ? q{P} : q{-};
    push @text,
        $nook->[Marpa::R2::Internal::Nook::CAUSE_IS_EXPANDED] ? q{C+} : q{--};
    push @text,
        $nook->[Marpa::R2::Internal::Nook::PREDECESSOR_IS_EXPANDED]
        ? q{P+}
        : q{--};
    $text .= join q{ }, @text;
    $text
        .= ' @'
        . $nook->[Marpa::R2::Internal::Nook::FIRST_CHOICE] . q{-}
        . $nook->[Marpa::R2::Internal::Nook::LAST_CHOICE]
        . qq{ of $and_node_count: };
    $text .= $recce->verbose_or_node($or_node_id);
    return $text;
} ## end sub dump_nook

# For debugging
sub dump_factoring_stack {
    my ( $asf, $stack ) = @_;
    my $text = q{};
    for ( my $stack_ix = 0; $stack_ix <= $#{$stack}; $stack_ix++ ) {

        # Nook already has newline at end
        $text .= "$stack_ix: " . dump_nook( $asf, $stack->[$stack_ix] );
    }
    return $text . "\n";
} ## end sub dump_factoring_stack

1;

# vim: expandtab shiftwidth=4:
