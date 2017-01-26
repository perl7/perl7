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

    proto token statement {*}
    token statement:sym<EXPR> { <EXPR> }
    token statement:sym<💬> {
        <.ws> <sym> <.ws> <EXPR>
    }
    token statement:sym<fuc> {
        'fuc' \h+ <fucbody>
    }
    rule fucbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
            <ident> \n
            <statementlist>
        'ton'
    }

    proto token sign {*}
    token sign:sym<−> { '−'  }
    token sign:sym<+> { '+'? }

    proto token value {*}
    token value:sym<string> { <?["']> <quote_EXPR: ':q'> }
    token value:sym<integer> { <sign> $<num>=\d+ }
    token value:sym<float>   { <sign> $<num>=[\d+ '.' \d+] }

    token term:sym<value> { <value> }
    token term:sym<ident> {
        :my $*MAYBE_DECL := 0;
        <ident>
        [ <?before \h* '=' [\w|\h+] { $*MAYBE_DECL := 1 }> || <?> ]
    }
    token term:sym<call> {
        <!keyword>
        <ident> '[' ']'
    }

    token keyword {
        [ fuc | ton ]
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

grammar Perl7::Actions is HLL::Actions {
    method TOP($/) {
        $*CUR_BLOCK[0].push:
            QAST::Var.new(:name<@*ARGS>, :scope<local>, :decl<param>);
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
    method statement:sym<fuc>($/) {
        my $install := $<fucbody>.ast;
        $*CUR_BLOCK[0].push(
            QAST::OP.new(
                :op<bind>,
                QAST::Var.new(
                    :name($install.name), :scope<lexical>, :decl<var>
                ),
                $install,
            )
        );
        make QAST::OP.new(:op<null>);
    }
    method fucbody($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push($<statementlist>.ast);
        make $*CUR_BLOCK;
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
    method term:sym<ident>($/) {
        my $name := ~$<ident>;
        my %sym := $*CUR_BLOCK.symbol($name);
        if $*MAYBE_DECL && !%sym<declared> {
            $*CUR_BLOCK.symbol($name, :declared);
            make QAST::Var.new(:$name, :scope<lexical>, :decl<var>);
        } else {
            make QAST::Var.new(:$name, :scope<lexical> )
        }
    }
    method term:sym<call>($/) {
        make QAST::Op.new( :op<call>, :name(~$<ident>) );
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
