package com.example.gamepadvirtual

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface
import kotlin.concurrent.thread

class DiscoveryService : Service() {

    private var isRunning = false
    private lateinit var discoveryThread: Thread
    private var socket: DatagramSocket? = null

    companion object {
        const val NOTIFICATION_ID = 1002
        const val CHANNEL_ID = "discovery_service_channel"
        const val DISCOVERY_PORT = 27016
        val DISCOVERY_QUERY = "DISCOVER_GAMEPAD_VIRTUAL_SERVER".toByteArray()

        const val SERVER_FOUND_ACTION = "com.example.gamepadvirtual.SERVER_FOUND"
        const val EXTRA_SERVER_NAME = "serverName"
        const val EXTRA_SERVER_IP = "serverIp"
    }

    // --- INICIALIZAÇÃO DO SERVIÇO ---
    // Cria o canal de notificação quando o serviço é criado
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    // --- COMANDO DE INÍCIO ---
    // Inicia o serviço em primeiro plano com notificação
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_SERVICE") {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!isRunning) {
            isRunning = true
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
            startDiscovery()
        }
        return START_STICKY
    }

    // --- SERVIÇO DE DESCOBERTA MODIFICADO ---
    // Agora envia pacotes para Wi-Fi E Ancoragem USB
    private fun startDiscovery() {
        discoveryThread = thread {
            try {
                socket = DatagramSocket()
                socket?.broadcast = true

                // Thread para ouvir as respostas (sem mudanças)
                thread {
                    listenForResponses()
                }

                // Loop para enviar a query de descoberta
                while (isRunning) {
                    try {
                        // --- LÓGICA DE DESCOBERTA MODIFICADA ---
                        
                        // 1. Pega todos os endereços de broadcast (Wi-Fi, USB, etc.)
                        val broadcastAddresses = getBroadcastAddresses()
                        
                        // 2. Envia para o broadcast global (para Wi-Fi padrão)
                        val globalBroadcast = InetAddress.getByName("255.255.255.255")
                        val packetGlobal = DatagramPacket(DISCOVERY_QUERY, DISCOVERY_QUERY.size, globalBroadcast, DISCOVERY_PORT)
                        socket?.send(packetGlobal)

                        // 3. Envia para os broadcasts de sub-rede (para Ancoragem USB)
                        broadcastAddresses.forEach { broadcastAddr ->
                            try {
                                val packetSubnet = DatagramPacket(DISCOVERY_QUERY, DISCOVERY_QUERY.size, broadcastAddr, DISCOVERY_PORT)
                                socket?.send(packetSubnet)
                            } catch (e: Exception) {
                                // Ignora erros de envio da sub-rede
                            }
                        }
                        // --- FIM DA MODIFICAÇÃO ---

                    } catch (e: Exception) {
                        // Ignora erros de envio
                    }
                    Thread.sleep(3000)
                }
            } catch (e: Exception) {
                // Erro ao criar o socket
            } finally {
                socket?.close()
            }
        }
    }

    // --- NOVA FUNÇÃO ADICIONADA ---
    // Encontra endereços de broadcast de todas as interfaces de rede
    private fun getBroadcastAddresses(): List<InetAddress> {
        val broadcastList = mutableListOf<InetAddress>()
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                
                // Ignora interfaces que estão desligadas ou são de loopback
                if (!networkInterface.isUp || networkInterface.isLoopback) {
                    continue
                }
                
                networkInterface.interfaceAddresses.forEach { interfaceAddress ->
                    interfaceAddress.broadcast?.let {
                        broadcastList.add(it)
                    }
                }
            }
        } catch (ex: Exception) {
            // Ignora erros ao listar interfaces
        }
        return broadcastList.distinct() // Retorna apenas endereços únicos
    }

    // --- ESCUTA DE RESPOSTAS ---
    // Processa respostas dos servidores encontrados
    private fun listenForResponses() {
        val buffer = ByteArray(1024)
        val packet = DatagramPacket(buffer, buffer.size)
        while (isRunning) {
            try {
                socket?.receive(packet)
                val response = String(packet.data, 0, packet.length)
                if (response.startsWith("GAMEPAD_VIRTUAL_SERVER_ACK:")) {
                    val serverName = response.substringAfter("GAMEPAD_VIRTUAL_SERVER_ACK:")
                    val serverIp = packet.address.hostAddress

                    // Envia os dados do servidor encontrado para a MainActivity
                    val intent = Intent(SERVER_FOUND_ACTION).apply {
                        putExtra(EXTRA_SERVER_NAME, serverName)
                        putExtra(EXTRA_SERVER_IP, serverIp)
                    }
                    sendBroadcast(intent)
                }
            } catch (e: Exception) {
                // Ignora erros de recebimento
            }
        }
    }

    // --- DESTRUIÇÃO DO SERVIÇO ---
    // Limpa recursos quando o serviço é parado
    override fun onDestroy() {
        isRunning = false
        socket?.close()
        discoveryThread.interrupt()
        super.onDestroy()
    }

    // --- BIND DO SERVIÇO ---
    // Serviço não vinculado, retorna null
    override fun onBind(intent: Intent?): IBinder? = null

    // --- CRIAÇÃO DA NOTIFICAÇÃO ---
    // Cria a notificação de serviço em primeiro plano
    private fun createNotification(): Notification {
        val stopIntent = Intent(this, DiscoveryService::class.java).apply { action = "STOP_SERVICE" }
        val pendingStopIntent = PendingIntent.getService(this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GamePadVirtual")
            .setContentText("Procurando servidor na rede...")
            .setSmallIcon(R.drawable.ic_stat_name) // Você precisará criar este ícone
            .addAction(0, "Parar", pendingStopIntent)
            .setOngoing(true)
            .build()
    }

    // --- CRIAÇÃO DO CANAL DE NOTIFICAÇÃO ---
    // Cria o canal de notificação para Android 8+
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Serviço de Descoberta",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}