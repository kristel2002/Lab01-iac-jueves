// hello/index.js - Función Lambda con manejo de SQS, SNS y S3

const AWS = require('aws-sdk');

// Inicializar clientes AWS
const s3 = new AWS.S3();
const sns = new AWS.SNS();
const sqs = new AWS.SQS();

// Variables de entorno
const S3_BUCKET = process.env.S3_BUCKET_NAME;
const SNS_TOPIC = process.env.SNS_TOPIC_ARN;
const SQS_QUEUE = process.env.SQS_QUEUE_URL;

// Handler principal
exports.handler = async (event, context) => {
    console.log('Evento recibido:', JSON.stringify(event, null, 2));
    console.log('Contexto:', JSON.stringify(context, null, 2));
    
    try {
        // Detectar el tipo de evento
        if (event.Records && event.Records[0].eventSource === 'aws:sqs') {
            // Evento de SQS
            return await handleSQSEvent(event);
        } 
        else if (event.Records && event.Records[0].eventSource === 'aws:s3') {
            // Evento de S3
            return await handleS3Event(event);
        }
        else if (event.Records && event.Records[0].EventSource === 'aws:sns') {
            // Evento de SNS
            return await handleSNSEvent(event);
        }
        else {
            // Evento directo (API Gateway o test)
            return await handleDirectEvent(event);
        }
    } catch (error) {
        console.error('Error en Lambda:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: error.message,
                timestamp: new Date().toISOString()
            })
        };
    }
};

// ============================================
// MANEJADOR DE EVENTOS SQS
// ============================================

async function handleSQSEvent(event) {
    console.log('📨 Procesando mensajes de SQS...');
    
    const batchItemFailures = [];
    
    for (const record of event.Records) {
        try {
            // Parsear el mensaje
            const message = JSON.parse(record.body);
            console.log(`Procesando mensaje ID: ${record.messageId}`);
            console.log('Contenido:', message);
            
            // Procesar según el tipo de mensaje
            if (message.type === 'notification') {
                await processNotification(message);
            } else if (message.type === 'task') {
                await processTask(message);
            } else {
                await processGenericMessage(message);
            }
            
            console.log(`✅ Mensaje ${record.messageId} procesado exitosamente`);
            
        } catch (error) {
            console.error(`❌ Error procesando mensaje ${record.messageId}:`, error);
            batchItemFailures.push({
                itemIdentifier: record.messageId
            });
        }
    }
    
    // Reportar fallos para reintento (partial batch response)
    return {
        batchItemFailures: batchItemFailures
    };
}

// ============================================
// MANEJADOR DE EVENTOS S3
// ============================================

async function handleS3Event(event) {
    console.log('☁️ Procesando eventos de S3...');
    
    for (const record of event.Records) {
        try {
            const bucket = record.s3.bucket.name;
            const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
            const eventName = record.eventName;
            
            console.log(`Archivo: ${bucket}/${key}`);
            console.log(`Evento: ${eventName}`);
            
            if (eventName.includes('ObjectCreated')) {
                // Archivo subido - procesarlo
                await processUploadedFile(bucket, key);
            } else if (eventName.includes('ObjectRemoved')) {
                // Archivo eliminado
                await processDeletedFile(bucket, key);
            }
            
            // Enviar notificación SNS
            await sns.publish({
                TopicArn: SNS_TOPIC,
                Subject: 'Archivo procesado en S3',
                Message: JSON.stringify({
                    bucket: bucket,
                    key: key,
                    event: eventName,
                    timestamp: new Date().toISOString()
                })
            }).promise();
            
            console.log(`✅ Archivo ${key} procesado`);
            
        } catch (error) {
            console.error('Error procesando archivo S3:', error);
            // Enviar a SQS para reintentar
            await sendToDLQ(event);
        }
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Eventos S3 procesados' })
    };
}

// ============================================
// MANEJADOR DE EVENTOS SNS
// ============================================

async function handleSNSEvent(event) {
    console.log('📢 Procesando notificaciones de SNS...');
    
    for (const record of event.Records) {
        try {
            const snsMessage = record.Sns;
            console.log(`Mensaje SNS ID: ${snsMessage.MessageId}`);
            console.log(`Asunto: ${snsMessage.Subject}`);
            console.log(`Mensaje: ${snsMessage.Message}`);
            
            const message = JSON.parse(snsMessage.Message);
            
            // Procesar según la prioridad
            if (message.priority === 'high') {
                await processHighPriorityNotification(message);
            } else {
                await processNormalNotification(message);
            }
            
            console.log(`✅ Notificación ${snsMessage.MessageId} procesada`);
            
        } catch (error) {
            console.error('Error procesando notificación SNS:', error);
        }
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Notificaciones SNS procesadas' })
    };
}

// ============================================
// EVENTO DIRECTO (API Gateway o Test)
// ============================================

async function handleDirectEvent(event) {
    console.log('🎯 Procesando evento directo...');
    
    const response = {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Lambda ejecutada exitosamente',
            input: event,
            timestamp: new Date().toISOString(),
            services: {
                s3_bucket: S3_BUCKET,
                sns_topic: SNS_TOPIC,
                sqs_queue: SQS_QUEUE
            }
        })
    };
    
    // Si hay un mensaje, enviarlo a SQS
    if (event.body) {
        const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        
        if (body.message) {
            await sendToSQS({
                message: body.message,
                priority: body.priority || 'normal',
                source: 'direct-invoke'
            });
            
            response.body = JSON.stringify({
                ...JSON.parse(response.body),
                sqs_sent: true,
                message_id: messageId
            });
        }
    }
    
    return response;
}

// ============================================
// FUNCIONES AUXILIARES
// ============================================

// Procesar archivo subido a S3
async function processUploadedFile(bucket, key) {
    // Obtener el archivo de S3
    const object = await s3.getObject({
        Bucket: bucket,
        Key: key
    }).promise();
    
    console.log(`Tamaño del archivo: ${object.ContentLength} bytes`);
    console.log(`Tipo: ${object.ContentType}`);
    
    // Aquí puedes agregar tu lógica de negocio
    // Por ejemplo: procesar imagen, extraer texto, etc.
    
    // Guardar metadata (ejemplo)
    const metadata = {
        key: key,
        size: object.ContentLength,
        type: object.ContentType,
        processedAt: new Date().toISOString(),
        processedBy: 'lambda-seabook'
    };
    
    // Guardar metadata como un archivo JSON en S3
    await s3.putObject({
        Bucket: bucket,
        Key: `metadata/${key}.json`,
        Body: JSON.stringify(metadata, null, 2),
        ContentType: 'application/json'
    }).promise();
    
    return metadata;
}

// Procesar archivo eliminado
async function processDeletedFile(bucket, key) {
    console.log(`Archivo eliminado: ${key}`);
    // Limpiar metadata si existe
    try {
        await s3.deleteObject({
            Bucket: bucket,
            Key: `metadata/${key}.json`
        }).promise();
    } catch (error) {
        console.log('No metadata found for:', key);
    }
}

// Procesar notificación de alta prioridad
async function processHighPriorityNotification(message) {
    console.log('🔴 PROCESANDO NOTIFICACIÓN DE ALTA PRIORIDAD');
    // Acciones inmediatas: enviar email, alerta, etc.
    console.log('Contenido:', message);
}

// Procesar notificación normal
async function processNormalNotification(message) {
    console.log('🟢 Procesando notificación normal');
    console.log('Contenido:', message);
}

// Procesar tarea de SQS
async function processTask(task) {
    console.log(`Ejecutando tarea: ${task.id}`);
    console.log(`Payload:`, task.payload);
    // Lógica de la tarea aquí
}

// Procesar notificación genérica
async function processGenericMessage(message) {
    console.log('Mensaje genérico:', message);
}

// Procesar notificación de evento
async function processNotification(notification) {
    console.log('Notificación:', notification);
}

// Enviar mensaje a SQS
async function sendToSQS(message) {
    const params = {
        QueueUrl: SQS_QUEUE,
        MessageBody: JSON.stringify(message),
        MessageAttributes: {
            Priority: {
                DataType: 'String',
                StringValue: message.priority || 'normal'
            }
        }
    };
    
    const result = await sqs.sendMessage(params).promise();
    console.log(`Mensaje enviado a SQS: ${result.MessageId}`);
    return result.MessageId;
}

// Enviar a Dead Letter Queue
async function sendToDLQ(event) {
    // Implementar lógica para enviar mensajes fallidos a DLQ
    console.log('Enviando a DLQ...');
}