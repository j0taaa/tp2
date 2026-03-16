# TP2 / PA2 (COOL) - Análise Léxica

Este repositório contém a implementação do *scanner* (analisador léxico) para a linguagem **COOL** (Classroom Object-Oriented Language), equivalente ao Programming Assignment 2 (PA2).

O objetivo do PA2 é implementar um lexer que:

- reconhece todos os tokens definidos pela infraestrutura do compilador (via `cool-parse.h` no ambiente do curso);
- reporta erros léxicos com as **mensagens exigidas**;
- mantém `curr_lineno` correto (inclusive dentro de comentários e strings);
- permite que as fases seguintes do compilador rodem quando a entrada é lexicamente válida.

<!-- 
## Pastas (PA2 vs PA2J)

- `PA2/`: implementação **C++ + Flex**. A lógica do lexer está em `PA2/cool.flex` e os testes versionados estão em `PA2/test.cl` e `PA2/test.output`.
- `PA2J/`: alternativa **Java + JLex**. Neste repositório, `PA2J/cool.lex` ainda é o *skeleton* do curso (não há write-up nem regras completas), portanto a entrega efetiva está em `PA2/`. -->

## Como compilar e executar

Este projeto segue a infraestrutura padrão do curso (caminhos como `/var/tmp/cool`).

Observação importante para este clone no Windows:

- alguns arquivos (ex.: `PA2/Makefile`, `PA2/mycoolc`, `PA2/parser`, `PA2/semant`, `PA2/cgen`) aparecem aqui como "stubs" contendo um caminho para o arquivo real no ambiente do curso;
- o binário `PA2/lexer` presente no repo é um ELF Linux (x86_64), então não executa nativamente no Windows.

No ambiente correto do curso (Linux/VM/WSL configurado com `/var/tmp/cool`), os comandos esperados são:

```sh
cd PA2
gmake lexer
./lexer test.cl
gmake dotest
```

O alvo `dotest` deve gerar/atualizar `PA2/test.output` com a saída do driver `lextest` (tokens impressos com número de linha).

Observação: na infraestrutura original do PA2, a entrega costuma coletar os arquivos dentro de `PA2/` (por exemplo: `cool.flex`, `test.cl`, `README`, `test.output`). Por isso, além deste `README.md` na raiz, o write-up principal está (ou deve estar) em `PA2/README`.

## Implementação do lexer

A implementação está concentrada em `PA2/cool.flex`.

Estados léxicos do Flex:

- estado padrão `INITIAL`;
- 3 estados exclusivos declarados: `COMMENT`, `STRING`, `STRING_ERROR`.

### Espaços, novas linhas e comentários

- `WHITESPACE` (espaço, tab, etc.) é ignorado.
- `NEWLINE` incrementa `curr_lineno`.
- comentário de linha: `"--"[^\n]*` é ignorado.
- comentário de bloco aninhado: ao ler `"(*"` entra em `COMMENT` e usa `comment_depth` para controlar aninhamento.
  - cada `"(*"` incrementa `comment_depth`
  - cada `"*)"` decrementa; ao voltar a `0`, retorna ao `INITIAL`
  - `EOF` ainda em `COMMENT` retorna `ERROR` com `EOF in comment`
  - `*)` em `INITIAL` retorna `ERROR` com `Unmatched *)`

### Operadores e pontuação

Reconhece operadores de mais de um caractere:

- `=>` -> `DARROW`
- `<-` -> `ASSIGN`
- `<=` -> `LE`

E retorna os de um caractere diretamente: `+ / - * = < . ~ , ; : ( ) @ { }`.

### Palavras-chave, identificadores, inteiros e booleanos

- palavras-chave são **case-insensitive** (por regex) para: `class`, `else`, `fi`, `if`, `in`, `inherits`, `let`, `loop`, `pool`, `then`, `while`, `case`, `esac`, `of`, `new`, `isvoid`, `not`.
- booleanos seguem a regra do enunciado: só viram `BOOL_CONST` se **começarem com letra minúscula**:
  - `true` (ou variações como `tRuE`) -> `BOOL_CONST` com valor `1`
  - `false` (ou variações como `fAlSe`) -> `BOOL_CONST` com valor `0`
  - `True`/`False` não são booleanos; viram `TYPEID` por começarem com maiúscula.
- inteiros: `{DIGIT}+` -> `INT_CONST` e entra na `inttable`.
- identificadores:
  - começando com maiúscula: `TYPEID`
  - começando com minúscula: `OBJECTID`
  - `SELF_TYPE` e `self` são tratados como identificadores normais (tipo/objeto) por essas regras.

### Strings e recuperação de erro

Strings são iniciadas por `\"`, acumuladas em `string_buf` e finalizadas por outra `\"`.

Escapes tratados em `STRING`:

- `\\n`, `\\t`, `\\b`, `\\f`
- `\\\n` (barra + newline): incrementa `curr_lineno` e adiciona `\n` ao buffer
- `\\c` para qualquer outro `c`: adiciona `c`

Erros e mensagens (tokens `ERROR`) implementados explicitamente:

- `EOF in string constant` (EOF ainda em `STRING` ou `STRING_ERROR`)
- `Unterminated string constant` (newline não escapada dentro de `STRING`)
- `String constant too long` (buffer excede `MAX_STR_CONST - 1`)
- `String contains null character` (byte `\0` dentro de string)

Recuperação: ao detectar `String constant too long` ou `String contains null character`, o lexer entra em `STRING_ERROR` e continua consumindo até fechar aspas (`\"`) ou até newline/EOF, evitando "cascata" de erros a partir da mesma string.

Nota sobre `\\0`: pela regra geral do enunciado (escape `\\c` vira `c`), a sequência textual `\\0` vira o caractere `'0'` e **não** deve disparar `String contains null character`. O erro `String contains null character` só acontece quando existe um byte `\0` real dentro do arquivo de entrada.

### Caractere inválido

Qualquer caractere que não case com nenhuma regra retorna `ERROR` contendo apenas aquele caractere (em `cool_yylval.error_msg`).

## Testes

Os testes versionados para o PA2 estão em:

- `PA2/test.cl`: bateria principal (tokens válidos + erros recuperáveis)
- `PA2/test.output`: saída de referência ao rodar `./lexer test.cl` (via `gmake dotest`)

O `PA2/test.cl` exercita, em um único arquivo:

- palavras-chave com mistura de maiúsculas/minúsculas (ex.: `cLaSs`, `InHeRiTs`)
- `TYPEID` vs `OBJECTID` e casos-limite (`SELF_TYPE`, `self`, `True`/`False`)
- inteiros e operadores (`<-`, `<=`, `=>`, e operadores de 1 caractere)
- strings válidas e escapes (incluindo `\\n`, `\\t`, `\\b`, `\\f`, `\\\"`, `\\\\`)
- comentário de linha e comentário de bloco com aninhamento
- erros léxicos recuperáveis no meio do arquivo (confirmados em `PA2/test.output`):
  - `*)` fora de comentário -> `Unmatched *)` (ex.: linha `#34`)
  - caractere inválido `#` -> `ERROR "#"` (ex.: linha `#35`)
  - string sem fechar antes da quebra de linha -> `Unterminated string constant` (ex.: linha `#37`)

### Casos de canto recomendados

Alguns requisitos são difíceis de manter dentro de um `test.cl` "normal" porque dependem de `EOF` ou de byte nulo real.

O lexer implementa as mensagens exigidas para:

- `EOF in comment`
- `EOF in string constant`
- `String constant too long`
- `String contains null character`

Para ficar totalmente reprodutível (e atender ao requisito de "bateria de testes"), recomenda-se versionar arquivos dedicados (um por caso) e documentar no write-up.

## Dificuldades e soluções

- **Atualização de `curr_lineno` em todos os estados**: incremento em `INITIAL`, `COMMENT` e `STRING` (incluindo `\\\n`) para manter a numeração correta.
- **Delimitar o fim de uma string inválida**: uso de `STRING_ERROR` para consumir até aspas/newline/EOF e evitar cascata.
- **Mensagens exatas**: textos de erro mantidos exatamente como especificados para bater com testes automatizados.
