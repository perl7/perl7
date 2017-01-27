#!/usr/bin/env nqp

use NQPHLL;

grammar Perl7::Grammar is HLL::Grammar {
    token TOP {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <statementlist>
        [ $ || <.panic('Syntax error')> ]
    }
    token ws { <!ww> \h* || \h+ }

    rule statementlist { [ <statement> "\n"+ ]* }
    token apostrophe { <['-]> }
    token identifier { <.ident> [ <.apostrophe> <.ident> ]* }

    proto token statement {*}
    token statement:sym<EXPR> { <EXPR> }
    token statement:sym<💬> { # U+1F4AC
        <sym> <.ws> <EXPR>
    }
    token statement:sym<fun> {
        'fun' \h+ <funbody>
    }
    rule funbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <identifier> <signature>? \n
        <statementlist>
        'ion'
    }
    rule signature {
        '[' <param>* % [ ',' ] ']'
    }
    token param { <identifier> }

    proto token sign {*}
    token sign:sym<−> { '−'  }
    token sign:sym<+> { '+'? }

    proto token value {*}
    token value:sym<string> { <?["']> <quote_EXPR: ':q'> }
    token value:sym<integer> { <sign> $<num>=\d+ }
    token value:sym<float>   { <sign> $<num>=[\d+ '.' \d+] }

    token term:sym<call> {
        <!keyword>
        <identifier> <?{ $*CUR_BLOCK.symbol("&$<identifier>")<declared> }>
        [ '[' :s <EXPR>* % [ ',' ] ']' ]?
    }
    token term:sym<identifier> {
        :my $*MAYBE_DECL := 0;
        <!keyword>
        <identifier>
        [ <?before \h* '=' [\w|\h+] { $*MAYBE_DECL := 1 }> || <?> ]
    }
    token term:sym<value> { <value> }

    token keyword {
        [ 'fun' | 'ion' ]
        <!ww>
    }

    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left' );
    my %additive       := nqp::hash('prec', 't=', 'assoc', 'left' );
    my %assignment     := nqp::hash('prec', 'j=', 'assoc', 'right');

    token infix:sym<×> { <sym> <O(|%multiplicative, :op<mul_n>)> }
    token infix:sym<÷> { <sym> <O(|%multiplicative, :op<div_n>)> }
    token infix:sym<+> { <sym> <O(|%additive,       :op<add_n>)> }
    token infix:sym<−> { <sym> <O(|%additive,       :op<sub_n>)> }
    token infix:sym<=> { <sym> <O(|%assignment,     :op<bind> )> }

}

# Perl7::Grammar.HOW.trace-on(Perl7::Grammar);
grammar Perl7::Actions is HLL::Actions {
    method TOP($/) {
        $*CUR_BLOCK.push: $<statementlist>.ast;
        make $*CUR_BLOCK;
    }

    method statementlist($/) {
        my $stmts := QAST::Stmts.new( :node($/) );
        for $<statement> {
            $stmts.push($_.ast);
        }
        make $stmts;
    }

    method statement:sym<EXPR>($/) { make $<EXPR>.ast; }
    method statement:sym<💬>($/) {
        make QAST::Op.new( :op('say'), $<EXPR>.ast );
    }
    method statement:sym<fun>($/) {
        my $install := $<funbody>.ast;
        $*CUR_BLOCK.symbol($install.name, :declared);
        $*CUR_BLOCK[0].push(
            QAST::Op.new(
                :op<bind>,
                QAST::Var.new(
                    :name($install.name), :scope<lexical>, :decl<var>
                ),
                $install,
            )
        );
        make QAST::Op.new(:op<null>);
    }
    method funbody($/) {
        $*CUR_BLOCK.name("&$<identifier>");
        $*CUR_BLOCK.push($<statementlist>.ast);
        make $*CUR_BLOCK;
    }
    method param($/) {
        $*CUR_BLOCK[0].push:
            QAST::Var.new: :name(~$<identifier>), :scope<lexical>, :decl<param>;
        $*CUR_BLOCK.symbol: ~$<identifier>, :declared;
    }

    method sign:sym<−>($/) { make '-' }
    method sign:sym<+>($/) { make ''  }

    method value:sym<string>($/) { make $<quote_EXPR>.ast; }
    method value:sym<integer>($/) {
        make QAST::IVal.new: value => +($<sign>.made ~ $<num>);
    }
    method value:sym<float>($/) {
        make QAST::NVal.new: value => +($<sign>.made ~ $<num>);
    }

    method term:sym<value>($/) { make $<value>.ast; }
    method term:sym<identifier>($/) {
        my $name := ~$<identifier>;
        my %sym := $*CUR_BLOCK.symbol($name);
        if $*MAYBE_DECL && !%sym<declared> {
            $*CUR_BLOCK.symbol: $name, :declared;
            make QAST::Var.new: :$name, :scope<lexical>, :decl<var>;
        } else {
            make QAST::Var.new: :$name, :scope<lexical>;
        }
    }
    method term:sym<call>($/) {
        my $call := QAST::Op.new: :op<call>, :name("&$<identifier>");
        for $<EXPR> {
            $call.push: $_.ast;
        }
        make $call;
    }
}

grammar Perl7::Compiler is HLL::Compiler {
    method eval($code, *@_args, *%adverbs) {
        my $output := self.compile($code, :compunit_ok(1), |%adverbs);

        if %adverbs<target> eq '' {
            my $outer_ctx := %adverbs<outer_ctx>;
            $output := self.backend.compunit_mainline($output);
            if nqp::defined($outer_ctx) {
                nqp::forceouterctx($output, $outer_ctx);
            }

            $output := $output();
        }

        $output;
    }
}

sub MAIN (*@ARGS) {
    my $comp := Perl7::Compiler.new;
    $comp.language('Perl7');
    $comp.parsegrammar(Perl7::Grammar);
    $comp.parseactions(Perl7::Actions);
    $comp.command_line(@ARGS, :encoding<utf8>);
}
