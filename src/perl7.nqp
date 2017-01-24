#!/usr/bin/env nqp

use NQPHLL;

grammar Perl7::Grammar is HLL::Grammar {
    token TOP { <statementlist> }
    token ws { <!ww> \h* || \h+ }

    rule statementlist { [ <statement> "\n"+ ]* }

    proto token statement {*}
    token statement:sym<💬> {
        <sym> <.ws> <EXPR>
    }

    proto token value {*}
    token value:sym<string> { <?["']> <quote_EXPR: ':q'> }
    token value:sym<integer> { '-'? \d+ }
    token value:sym<float>   { '-'? \d+ '.' \d+ }

    token term:sym<value> { <value> }

    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left');
    my %additive       := nqp::hash('prec', 't=', 'assoc', 'left');

    token infix:sym<✖> { <sym> <O(|%multiplicative, :op<mul_n>)> }
    token infix:sym<➗> { <sym> <O(|%multiplicative, :op<div_n>)> }
    token infix:sym<➕> { <sym> <O(|%additive,       :op<add_n>)> }
    token infix:sym<➖> { <sym> <O(|%additive,       :op<sub_n>)> }

}

grammar Perl7::Actions is HLL::Actions {
    method TOP($/) {
        make QAST::Block.new(
            QAST::Var.new(:name<@*ARGS>, :scope<local>, :decl<param>),
            $<statementlist>.ast,
        );
    }

    method statementlist($/) {
        my $stmts := QAST::Stmts.new( :node($/) );
        for $<statement> {
            $stmts.push($_.ast);
        }
        make $stmts;
    }

    method statement:sym<💬>($/) {
        make QAST::Op.new( :op('say'), $<EXPR>.ast );
    }

    method value:sym<string>($/) { make $<quote_EXPR>.ast; }
    method value:sym<integer>($/) {
        make QAST::IVal.new: :value(+$/.Str);
    }
    method value:sym<float>($/) {
        make QAST::NVal.new: :value(+$/.Str);
    }

    method term:sym<value>($/) {
        make $<value>.ast;
    }
}

grammar Perl7::Compiler is HLL::Compiler {
}

sub MAIN (*@ARGS) {
    my $comp := Perl7::Compiler.new;
    $comp.language('Perl7');
    $comp.parsegrammar(Perl7::Grammar);
    $comp.parseactions(Perl7::Actions);
    $comp.command_line(@ARGS, :encoding<utf8>);
}
