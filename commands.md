===================================================================
 SERVERMANAGER — GUIA COMPLETO DE COMANDOS
===================================================================


-------------------------------------------------------------------
 1) MENU PRINCIPAL (Main.ps1)
-------------------------------------------------------------------
Abra com start.bat. O menu fica em loop — depois de qualquer ação
ele volta pra tela principal, exceto a opção de sair.

 [1] Verificar / instalar / atualizar e iniciar servidor
     - Checa Java, Forge, Minecraft e a versão do Forge
     - Instala o Forge automaticamente se não existir
     - Faz backup antes de qualquer atualização
     - Restaura sozinho se uma atualização falhar
     - Mostra um resumo e pergunta se quer iniciar o servidor

 [2] Restaurar backup manualmente
     - Lista os backups em /backups (mais recente primeiro)
     - Salva o estado atual antes de restaurar (backup de segurança)
     - ENTER sem digitar nada = voltar sem restaurar

 [3] Limpar temporários
     - Esvazia a pasta /temp

 [4] Gerenciar mods
     - [1] Buscar e instalar mod (via Modrinth)
     - [2] Listar mods instalados

 [5] Editar server.properties
     - Editor rápido de motd, max-players, difficulty, gamemode,
       pvp, view-distance, white-list, online-mode, command-block

 [6] Diagnóstico do sistema
     - Java, RAM livre, espaço em disco, porta 25565, internet,
       EULA, status do RCON e do Discord webhook

 [7] Ver log do servidor
     - Mostra as últimas 40 linhas de server/logs/latest.log

 [8] Controle remoto do servidor (parar/reiniciar/RCON)
     - Ver seção 2 abaixo (precisa de RCON habilitado)

 [9] Sair


-------------------------------------------------------------------
 2) CONTROLE REMOTO / DESLIGAR / REINICIAR (opção 8 do menu)
-------------------------------------------------------------------
Isso é o que você quer pra "desligar e reiniciar". Funciona mesmo
com o servidor rodando em OUTRA janela (usa RCON pela rede, não
precisa estar no mesmo console que iniciou o servidor).

 [1] Parar servidor (stop)
     - Avisa os jogadores 10s antes ("say Servidor será desligado...")
     - Manda save-all
     - Manda stop
     - Espera o processo encerrar de verdade (até 60s)

 [2] Reiniciar servidor (stop + start)
     - Mesma coisa do "Parar", e na sequência já chama o start
       de novo (reaplica RAM configurada e checa Forge/Java)

 [3] Salvar mundo agora (save-all)
     - Força um save sem parar o servidor

 [4] Listar jogadores online (list)

 [5] Anunciar mensagem (say)
     - Manda um aviso pro chat de todo mundo

 [6] Comando livre
     - Digite qualquer comando (ver lista completa na seção 3)


 COMO HABILITAR O RCON (obrigatório para a opção 8 funcionar):
 1. Abra config.json e defina:
        "rconEnabled": true,
        "rconPort": 25575,
        "rconPassword": "uma-senha-forte-aqui"
 2. Reinicie o servidor pelo menu [1] — o ServerManager escreve
    sozinho enable-rcon=true, rcon.port e rcon.password dentro de
    server.properties toda vez que o servidor inicia (função
    Sync-RconSettings). Você não precisa editar isso na mão.
 3. Se for a primeiríssima vez que o servidor roda, o
    server.properties só é criado depois do primeiro start — nesse
    caso o RCON só passa a valer a partir do 2º start.

-------------------------------------------------------------------
 3) COMANDOS DO MINECRAFT (digitados no console do servidor OU
    enviados via RCON pela opção [6] "Comando livre")
-------------------------------------------------------------------

 -- LIGAR / DESLIGAR / SALVAR --------------------------------------
 stop                          Desliga o servidor (salva antes)
 save-all                      Salva o mundo agora
 save-off                      Desativa o autosave (backups seguros)
 save-on                       Reativa o autosave
 reload                        Recarrega datapacks/whitelist/etc

-------------------------------------------------------------------
 4) start.bat
-------------------------------------------------------------------
 Duplo clique em start.bat abre o ServerManager (Main.ps1) com
 UTF-8 configurado e o menu principal descrito na seção 1.


-------------------------------------------------------------------
 5) DICAS RÁPIDAS
-------------------------------------------------------------------
 - Quer só reiniciar sem sair de casa? Menu [8] > [2].
 - Quer desligar com segurança antes de dormir? Menu [8] > [1].
 - Backup automático enquanto o servidor roda: defina
   "liveBackupIntervalMinutes" no config.json (0 = desativado).
   Se o RCON estiver ativo, o backup faz save-off/save-all/save-on
   sozinho, sem travar o mundo pros jogadores.
 - Se o servidor cair sozinho (crash), o ServerManager reinicia
   automaticamente até "maxRestartAttempts" vezes (config.json:
   "autoRestart" e "maxRestartAttempts").
 - Quer ser avisado no Discord de tudo isso (start/parada/crash/
   backup/update)? Cole a URL do webhook em "discordWebhookUrl"
   no config.json.
===================================================================
