#!/bin/bash
sed -i '' 's/public let discoveredPeers: AsyncStream<DevicePeer>//g' Sources/iTime/Services/Sync/MultipeerTransportService.swift
