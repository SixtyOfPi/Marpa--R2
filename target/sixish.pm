package Marpa::R2::Demo::Sixish1;

use 5.010;
use strict;
use warnings;

use Marpa::R2;

{
    my $file = './OP4.pm';
    unless ( my $return = do $file ) {
        warn "couldn't parse $file: $@" if $@;
        warn "couldn't do $file: $!" unless defined $return;
        warn "couldn't run $file" unless $return;
    }
}

my $OP_rules;
{

    $OP_rules = Marpa::R2::Demo::OP4::parse_rules( <<'END_OF_RULES');
    <start> ::= <concatenation>
    <concatenation> ::=
        <concatenation> ::= <concatenation> <opt ws> <quantified atom>
    <opt ws> ::=
    <opt ws> ::= <opt ws> <ws char>
    <quantified atom> ::= <atom> <opt ws> <quantifier>
    <quantified atom> ::= <atom>
    <atom> ::= <quoted literal>
        <quoted literal> ::= <single quote> <single quoted char seq> <single quote>
    <single quoted char seq> ::= <single quoted char>*
    <atom> ::= <self>
    <self> ::= '<~~>'
    <quantifier> ::= '*'
END_OF_RULES

require Data::Dumper; say Data::Dumper::Dumper($rules);
}

sub rule_by_name {
   my ($self, $name) = @_;
   my $rule = $self->{rule_by_name}->{$name};
   die qq{No rule with name "$name"} if not defined $rule;
   return $rule;
}

sub rule_name {
   my ($self, $rule_id) = @_;
   my $rule_name = $self->{rule_name}->[$rule_id];
   $rule_name = 'R' . $rule_id if not defined $rule_name;
   return $rule_name;
}

sub rule_name_set {
   my ($self, $name, $rule_id) = @_;
   $self->{rule_name}->[$rule_id] = $name;
   $self->{rule_by_name}->{$name} = $rule_id;
   return $rule_id;
}

sub rule_new {
    my ( $self, $ebnf ) = @_;
    my ( $lhs, $rhs ) = split /\s*[:][:][=]\s*/xms, $ebnf;
    die "Malformed EBNF: $ebnf" if not defined $lhs;
    $lhs =~ s/\A\s*//xms;
    $lhs =~ s/\s*\z//xms;
    my @rhs = split /\s+/xms, $rhs;
    return $self->{grammar}->rule_new( $self->symbol_by_name($lhs),
        [ map { $self->symbol_by_name($_) } @rhs ] );
} ## end sub rule_new

sub symbol_by_name {
   my ($self, $name) = @_;
   my $symbol = $self->{symbol_by_name}->{$name};
   die qq{No symbol with name "$name"} if not defined $symbol;
   return $symbol;
}

sub symbol_name {
   my ($self, $symbol_id) = @_;
   my $symbol_name = $self->{symbol_name}->[$symbol_id];
   $symbol_name = 'R' . $symbol_id if not defined $symbol_name;
   return $symbol_name;
}

sub symbol_name_set {
   my ($self, $name, $symbol_id) = @_;
   $self->{symbol_name}->[$symbol_id] = $name;
   $self->{symbol_by_name}->{$name} = $symbol_id;
   return $symbol_id;
}

sub symbol_new {
   my ($self, $name) = @_;
   return $self->symbol_name_set($name, $self->{grammar}->symbol_new());
}

sub dotted_rule {
    my ( $self, $rule_id, $dot_position ) = @_;
    my $grammar     = $self->{grammar};
    my $rule_length = $grammar->rule_length($rule_id);
    $dot_position = $rule_length if $dot_position < 0;
    my $lhs         = $self->symbol_name( $grammar->rule_lhs($rule_id) );
    my @rhs =
        map { $self->symbol_name( $grammar->rule_rhs( $rule_id, $_ ) ) }
        ( 0 .. $rule_length - 1 );
    $dot_position = 0 if $dot_position < 0;
    splice( @rhs, $dot_position, 0, q{.} );
    return join q{ }, $lhs, q{::=}, @rhs;
} ## end sub dotted_rule

sub progress_report {
    my ( $self, $recce, $ordinal ) = @_;
    my $result = q{};
    $ordinal //= $recce->latest_earley_set();
    $recce->progress_report_start($ordinal);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $origin ) = $recce->progress_item();
        last ITEM if not defined $rule_id; 
        $result
            .= q{@}
            . $origin . q{: }
            . $self->dotted_rule( $rule_id, $dot_position ) . "\n";
    } ## end ITEM: while (1)
    $recce->progress_report_finish();
    return $result;
} ## end sub progress_report

sub new {
    my ($class) = @_;
    my $sixish_grammar  = Marpa::R2::Thin::G->new( { if => 1 } );
    my %char_to_symbol  = ();
    my @regex_to_symbol = ();

    my $self = bless {}, $class;
    $self->{grammar} = $sixish_grammar;
    $self->{rule_by_name} = {};
    my $symbol_by_name = $self->{symbol_by_name} = {};
    $self->{rule_names} = {};
    $self->{symbol_names} = {};

    for my $char (split //xms, q{*<>~}) {
      $char_to_symbol{$char}  = $self->symbol_new(qq{'$char'});
    }
    $char_to_symbol{q{'}}  = $self->symbol_new('<single quote>');

    my $s_ws_char = $self->symbol_new('<ws char>');
    push @regex_to_symbol, [ qr/\s/xms, $s_ws_char ];
    my $s_single_quoted_char = $self->symbol_new('<single quoted char>');
    push @regex_to_symbol, [ qr/[^\\']/xms, $s_single_quoted_char ];

    SYMBOL: for my $symbol_name ( map { $_->{lhs}, @{ $_->{rhs} } }
        @{$OP_rules} )
    {
	next SYMBOL if $symbol_name =~ m{ \A ['] (.*) ['] \z }xms;
        if ( not defined $symbol_by_name->{$symbol_name} ) {
            my $symbol = $self->symbol_new($symbol_name);
        }
    } ## end for my $symbol_name ( map { $rule->{lhs}, @{ $rule->{...}}})

    RULE: for my $rule ( @{$OP_rules} ) {
        my $min = $rule->{min};
        my $lhs = $rule->{lhs};
        my $rhs = $rule->{rhs};
        if ( defined $min ) {
            $sixish_grammar->sequence_new(
                $self->symbol_by_name($lhs),
                $self->symbol_by_name( $rhs->[0] ),
                { min => $min }
            );
            next RULE;
        } ## end if ( defined $min )
        my @rhs_symbols = ();
        RHS_SYMBOL: for my $rhs_symbol_name ( @{$rhs} ) {
            if ($rhs_symbol_name =~ m{ \A ['] ([^']+) ['] \z }xms) {
		my $single_quoted_string = $1;
                push @rhs_symbols, map { $char_to_symbol{$_} } split //xms,
                    $single_quoted_string;
                next RHS_SYMBOL;
            }
            push @rhs_symbols, $self->symbol_by_name($rhs_symbol_name);
        } ## end RHS_SYMBOL: for my $rhs_symbol_name ( @{$rhs} )
        my $rule_id = $sixish_grammar->rule_new( $self->symbol_by_name($lhs),
            \@rhs_symbols );
    } ## end RULE: for my $rule ( @{$OP_rules} )

    # $sixish_grammar->rule_new( $self->symbol_by_name('self'),

    $sixish_grammar->start_symbol_set( $self->symbol_by_name('<start>'), );
    $sixish_grammar->precompute();

        $self->{grammar}         = $sixish_grammar;
        $self->{char_to_symbol}  = \%char_to_symbol;
        $self->{regex_to_symbol} = \@regex_to_symbol;
    return $self;
} ## end sub sixish_new

1;
