<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh-Hans.md">🇨🇳 简体中文</a> | <a href="README.zh-Hant.md">🇹🇼 繁體中文</a> | <a href="README.vi.md">🇻🇳 Tiếng Việt</a>
  <br>
  <a href="README.fr.md">🇫🇷 Français</a> | <a href="README.de.md">🇩🇪 Deutsch</a> | <a href="README.es.md">🇪🇸 Español</a> | <a href="README.pt.md">🇵🇹 Português</a> | <a href="README.th.md">🇹🇭 ไทย</a> | <a href="README.ar.md">🇸🇦 العربية</a>
</p>

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="Ícone do MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  Um app de barra de menus do macOS que normaliza com segurança nomes Unicode decompostos para NFC
</p>

<p align="center">
  <a href="#introdução">Introdução</a> ·
  <a href="#uso">Uso</a> ·
  <a href="#instalação-e-build">Instalação e build</a> ·
  <a href="#segurança-e-privacidade">Segurança</a> ·
  <a href="#desenvolvimento">Desenvolvimento</a>
</p>

## Introdução

MoaIMF é um app de barra de menus para macOS que normaliza nomes de arquivos e pastas em locais escolhidos pelo usuário para Unicode NFC. O nome se refere a reunir Initial, Medial e Final de uma sílaba hangul em uma forma composta.

No macOS, nomes de arquivos em coreano podem ser gravados em forma decomposta semelhante a NFD depois de passar por sistemas de arquivos, apps, ferramentas de download, descompactadores, discos externos, NAS ou sincronização em nuvem. O Finder pode mostrar `한글.txt`, enquanto Alfred, busca no terminal ou scripts veem `ㅎㅏㄴㄱㅡㄹ.txt` e não encontram o arquivo.

MoaIMF não é um script de limpeza de uso único. É um utilitário local que monitora continuamente pastas aprovadas pelo usuário e corrige problemas de nomes em arquivos recém-criados ou baixados.

## Capturas de tela

Enquanto monitora pastas, o ícone da barra de menus passa por `ㅎ`, `ㅏ`, `ㄴ`, `한`. Quando pausado, ele para em `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="Animação coreana da barra de menus do MoaIMF" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="Tela inglesa da barra de menus do MoaIMF" width="100%"></kbd>
    </td>
  </tr>
</table>

### Pastas monitoradas

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="Configurações de pastas monitoradas" width="100%"></kbd>

As configurações começam com `Downloads` como pasta padrão. Os botões `+` e `-` adicionam ou removem pastas monitoradas. Cada pasta pode ser ativada ou desativada separadamente.

### Exceções de estabilidade de download

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="Exceções de estabilidade de download" width="100%"></kbd>

Arquivos em download podem ainda não ter nome final, ou continuar mudando de tamanho e data de modificação. MoaIMF inclui regras bloqueadas para `.crdownload`, `.download`, `.part`, `.partial`, `.tmp` e permite regras personalizadas.

### Histórico recente

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="Histórico recente" width="100%"></kbd>

O histórico pode ser visto por hoje, 7 dias, 30 dias ou todo o período, e filtrado por renomeação, conflito, permissão ou erro. A busca também compara variantes normalizadas para tratar diferenças NFC/NFD como a mesma entrada.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### Sobre

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="Sobre o MoaIMF" width="100%"></kbd>

A janela About mostra nome, versão, descrição curta e copyright. A imagem mostra jamo decompostos sendo combinados em um caractere composto, como `ㅎㅏㄴ -> 한`.

## Recursos

- Ver estado na barra de menus, pausar, retomar e sair
- Usar Downloads como local monitorado padrão
- Gerenciar várias pastas com `+` e `-`
- Escanear pastas recursivamente
- Acessar apenas pastas escolhidas pelo usuário usando security-scoped bookmarks
- Detectar mudanças com FSEvents
- Processar apenas após tamanho e data de modificação estabilizarem
- Nunca sobrescrever automaticamente quando houver possível conflito
- Salvar histórico local de renomeações, conflitos, permissões e erros
- Sem servidor externo, conta ou telemetria

## Como funciona

MoaIMF não altera o conteúdo dos arquivos. Ele só trata a forma de normalização Unicode dos nomes de arquivos e pastas.

O fluxo é: escolher pasta, salvar permissão como bookmark, detectar mudanças via FSEvents, verificar exceções e estabilidade, calcular nome NFC, verificar conflitos, validar identidade antes e depois do rename e salvar o resultado.

MoaIMF não mescla arquivos em conflito nem cria automaticamente nomes como `-1`, `copy` ou `복사본`. Casos que exigem decisão do usuário ficam no histórico e em notificações.

## Uso

1. Abra `MoaIMF.app`; o ícone aparece na barra de menus.
2. Abra `Watched Folder Settings...` e adicione pastas.
3. Escolha `Normalize Existing Items` ou `Watch New Items Only`.
4. Use `Pause Watching` e `Resume Watching`.
5. Use `Scan All Now` ou `Scan Now` para escanear manualmente.
6. Escolha o idioma em `Language`.
7. Ative `Launch at Login` para iniciar ao fazer login.
8. Use `Quit MoaIMF` para sair sem deixar daemon ou helper.

Os idiomas fornecidos são traduções por IA para conveniência. Informe erros ou pedidos de novos idiomas em `Issues`.

## Instalação e build

Atualmente, MoaIMF é instalado a partir do código-fonte. Ainda não há pacote assinado com Developer ID e notarizado pela Apple.

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

Requisitos: macOS 13 Ventura ou posterior, Xcode 16 ou Command Line Tools compatíveis, Swift 6 toolchain e Git. Para construir apenas o bundle:

```sh
scripts/build-app.sh
```

## Dados locais

MoaIMF salva estado e histórico em Application Support dentro do sandbox container do app macOS.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Arquivos principais: `watched-folders.json`, `stability-rules.json`, `history.jsonl`, `recovery/`. Algumas configurações também ficam em `UserDefaults`.

## Segurança e privacidade

MoaIMF só altera nomes. Ele não lê nem modifica conteúdo, acessa apenas pastas escolhidas, não segue symlinks, não escaneia pacotes como `.app` ou `.photoslibrary`, verifica conflitos e funciona totalmente local. Sem rede, conta, analytics ou telemetria.

## Limitações

MoaIMF não altera o armazenamento de nomes do macOS no sistema todo, não força apps a salvar em NFC, não resolve conflitos automaticamente, não reconstrói índices Spotlight ou Alfred e atualmente foca em builds a partir do código-fonte.

## Desinstalação

1. Desative `Launch at Login`.
2. Escolha `Quit MoaIMF`.
3. Apague `MoaIMF.app`.
4. Para apagar estado local, remova a pasta Application Support do MoaIMF dentro do container do app.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Isso não reverte para NFD nomes que já foram alterados para NFC.

## Desenvolvimento

O projeto usa Swift Package Manager.

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [Especificação v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [Plano de implementação v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [Guia de contribuição](../CONTRIBUTING.md)
- [Política de segurança](../SECURITY.md)

## Licença

MoaIMF é distribuído sob a [MIT License](../LICENSE).
