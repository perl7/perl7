#!/usr/bin/env nqp

use NQPHLL;

class Perl7::ClassHOW {
    has $!name;
    has %!methods;
    has @!parents;

    method parents      { @!parents }
    method method_table { %!methods }

    method new_type(:$name!) {
        nqp::newtype(self.new(:$name), 'HashAttrStore');
    }
    method add_method($o, $name, $code) {
        %!methods{$name} := $code;
    }
    method find_method($o, $name) {
        %!methods{$name} // @!parents[0].method_table{$name} // nqp::null();
    }
    method add_parent($o, $parent) {
        die "Cannot have more than one parent" if @!parents;
        @!parents.push: $parent;
    }

    method compose($o) {
        nqp::setmethcache($o, %!methods);
        nqp::setmethcacheauth($o, 1);
    }
}

grammar Perl7::Grammar is HLL::Grammar {
    token TOP {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <statementlist>
        [ $ || <.panic('Perl 7 syntax error')> ]
    }
    token ws { <!ww> \h* || \h+ }

    rule statementlist { [ <statement> "\n"+ ]* }
    token apostrophe { <['-]> }
    token identifier { <.ident> [ <.apostrophe> <.ident> ]* }

    proto token statement {*}
    token statement:sym<EXPR> { <EXPR> }
    token statement:sym<say> {
        <sym> <.ws> <EXPR>
    }
    token statement:sym<routine> {
        'routine' \h+ <routinebody>
    }
    rule routinebody {
        :my $*CUR_BLOCK := QAST::Block.new: QAST::Stmts.new;
        <identifier> <signature>? \n
        <statementlist>
        'end'
    }
    rule signature {
        '(' <param>* % [ ',' ] ')'
    }
    token param { <identifier> }

    rule statement:sym<if> {
          'if' <statement> \n <statementlist>
        [ 'else' \n <else=.statementlist> ]?
        'end'
    }
    rule statement:sym<while> {
        'while' <statement> \n <statementlist>
        'end'
    }
    token statement:sym<class> {
        :my $*IN_CLASS := 1;
        :my @*METHODS;
        'class' \h+ [<parent> \h+]? <classbody>
    }
    rule parent {
        'is' <ident>
    }
    rule classbody {
        :my $*CUR_BLOCK := QAST::Block.new: QAST::Stmts.new;
        <ident> \n <statementlist> 'end'
    }

    proto token value {*}
    token value:sym<string> { <?["']> <quote_EXPR: ':q'> }
    token value:sym<integer> { <[+-]>? \d+ }
    token value:sym<float>   { <[+-]>? \d+ '.' \d+ }

    token term:sym<call> {
        <!keyword>
        <identifier> <?{ $*CUR_BLOCK.symbol("&$<identifier>")<declared> }>
        [ '(' :s <EXPR>* % [ ',' ] ')' ]?
    }
    token term:sym<identifier> {
        :my $*MAYBE_DECL := 0;
        <!keyword>
        <identifier>
        [ <?before \h* '=' [\w|\h+] { $*MAYBE_DECL := 1 }> || <?> ]
    }
    token term:sym<value> { <value> }
    token term:sym<new> {
        <ident> <.ws> '.new'
    }

    token keyword {
        [ routine | if | else | end | while | class | say | is ]
        <!ww>
    }

    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left' );
    my %additive       := nqp::hash('prec', 't=', 'assoc', 'left' );
    my %assignment     := nqp::hash('prec', 'j=', 'assoc', 'right');
    my %chaining       := nqp::hash('prec', 'm=', 'assoc', 'left' );
    my %methodop       := nqp::hash('prec', 'y=', 'assoc', 'unary');

    token infix:sym<*>  { <sym> <O(|%multiplicative, :op<mul_n>  )> }
    token infix:sym</>  { <sym> <O(|%multiplicative, :op<div_n>  )> }
    token infix:sym<+>  { <sym> <O(|%additive,       :op<add_n>  )> }
    token infix:sym<->  { <sym> <O(|%additive,       :op<sub_n>  )> }
    token infix:sym<=>  { <sym> <O(|%assignment,     :op<bind>   )> }
    token infix:sym«<»  { <sym> <O(|%chaining,       :op<islt_n> )> }
    token infix:sym«>»  { <sym> <O(|%chaining,       :op<isgt_n> )> }
    token infix:sym«<=» { <sym> <O(|%chaining,       :op<isle_n> )> }
    token infix:sym«>=» { <sym> <O(|%chaining,       :op<isge_n> )> }
    token infix:sym«!=» { <sym> <O(|%chaining,       :op<isne_n> )> }
    token infix:sym«==» { <sym> <O(|%chaining,       :op<iseq_n> )> }

    token postfix:sym<.> {
        <sym> <ident>
        [ '(' :s <EXPR>* % [ ',' ] ')' ]?
        <O(|%methodop)>
    }
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
    method statement:sym<say>($/) {
        make QAST::Op.new( :op('say'), $<EXPR>.ast );
    }
    method statement:sym<routine>($/) {
        my $install := $<routinebody>.ast;
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
        @*METHODS.push: $install if $*IN_CLASS;
        make QAST::Op.new(:op<null>);
    }
        method routinebody($/) {
            if $*IN_CLASS {
                $*CUR_BLOCK[0].unshift:
                    QAST::Var.new: :name<self>, :scope<lexical>, :decl<param>;
            }

            $*CUR_BLOCK.name("&$<identifier>");
            $*CUR_BLOCK.push($<statementlist>.ast);
            make $*CUR_BLOCK;
        }
        method param($/) {
            $*CUR_BLOCK[0].push:
                QAST::Var.new: :name(~$<identifier>),
                    :scope<lexical>, :decl<param>;
            $*CUR_BLOCK.symbol: ~$<identifier>, :declared;
        }

    method statement:sym<if>($/) {
        if $<else> {
            make QAST::Op.new(
                :op<if>,
                $<statement>.ast,
                $<statementlist>.ast,
                $<else>.ast,
            );
        } else {
            make QAST::Op.new(
                :op<if>,
                $<statement>.ast,
                $<statementlist>.ast,
            );
        }
    }
    method statement:sym<while>($/) {
        make QAST::Op.new(
            :op<while>,
            $<statement>.ast,
            $<statementlist>.ast,
        );
    }
    method statement:sym<class>($/) {
        my $body-block  := $<classbody>.ast;
        my $class-stmts := QAST::Stmts.new: $body-block;
        my $name        := $<classbody><ident>;
        $class-stmts.push: QAST::Op.new(
            :op<bind>,
            QAST::Var.new(:name('::' ~ $name), :scope<lexical>, :decl<var>),
            QAST::Op.new(
                :op<callmethod>, :name<new_type>,
                QAST::WVal.new(:value(Perl7::ClassHOW)),
                QAST::SVal.new(:value($name), :named<name>),
            )
        );

        my $class-var := QAST::Var.new: :name('::' ~ $name), :scope<lexical>;
        for @*METHODS {
            $class-stmts.push: QAST::Op.new(
                :op<callmethod>, :name<add_method>,
                QAST::Op.new(:op<how>, $class-var),
                $class-var,
                QAST::SVal.new(:value(nqp::substr($_.name,1))),
                QAST::BVal.new(:value($_)),
            );
        }

        $class-stmts.push: QAST::Op.new(
            :op<callmethod>, :name<compose>,
            QAST::Op.new(:op<how>, $class-var),
            $class-var,
        );

        make $class-stmts;
    }
        method parent($/) {
            make QAST::Var.new: :name('::' ~ $<ident>), :scope<lexical>;
        }
        method classbody($/) {
            $*CUR_BLOCK.push: $<statementlist>.ast;
            $*CUR_BLOCK.blocktype: 'immediate';
            make $*CUR_BLOCK;
        }


    method value:sym<string>($/) { make $<quote_EXPR>.ast; }
    method value:sym<integer>($/) {
        make QAST::IVal.new: value => +$/;
    }
    method value:sym<float>($/) {
        make QAST::NVal.new: value => +$/;
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
    method term:sym<new>($/) {
        make QAST::Op.new: :op<create>,
            QAST::Var.new: :name('::' ~ $<ident>), :scope<lexical>;
    }
    method postfix:sym<.>($/) {
        my $call := QAST::Op.new: :op<callmethod>, :name(~$<ident>);
        for $<EXPR> {
            $call.push: $_.ast;
        }
        make $call;
    }
}

grammar Perl7::Compiler is HLL::Compiler {
    method eval($code, *@_args, *%adverbs) {
        my $output := self.compile($code, :compunit_ok, |%adverbs);

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
